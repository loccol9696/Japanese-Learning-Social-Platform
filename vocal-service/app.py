import os
import shutil
import uuid
import torch
import asyncio
import subprocess
import sys
from contextlib import asynccontextmanager  # 1. Thêm import này
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from starlette.background import BackgroundTask
from urllib.parse import quote, urlparse

BASE_TEMP_DIR = "temp_processing"
os.makedirs(BASE_TEMP_DIR, exist_ok=True)
gpu_lock = asyncio.Lock()

# 2. Định nghĩa hàm lifespan thay thế cho @app.on_event
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Phần code chạy trước khi server nhận request (nếu cần)
    yield
    # Phần code chạy khi server tắt (tương đương với @app.on_event("shutdown"))
    if os.path.exists(BASE_TEMP_DIR):
        shutil.rmtree(BASE_TEMP_DIR, ignore_errors=True)

# 3. Gắn lifespan vào khởi tạo FastAPI
app = FastAPI(title="Demucs Vocal Isolator Service", lifespan=lifespan)

@app.post("/api/v1/separate-vocal")
async def separate_vocal(file: UploadFile = File(...)):
    task_id = str(uuid.uuid4())
    task_dir = os.path.join(BASE_TEMP_DIR, task_id)
    os.makedirs(task_dir, exist_ok=True)

    raw_video_path = os.path.join(task_dir, file.filename)
    audio_extracted_path = os.path.join(task_dir, "input.wav")
    output_dir = os.path.join(task_dir, "output")

    # 1. Lưu file video tải lên từ Spring Boot
    with open(raw_video_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # 2. Dùng FFmpeg bóc tách âm thanh sang WAV (chạy mất chưa tới 1 giây)
    ffmpeg_cmd = [
        "ffmpeg", "-y", "-i", raw_video_path,
        "-vn", "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2",
        audio_extracted_path
    ]
    ffmpeg_result = subprocess.run(
        ffmpeg_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if ffmpeg_result.returncode != 0:
        raise HTTPException(
            status_code=422,
            detail=f"FFmpeg could not extract audio: {ffmpeg_result.stderr[-4000:]}",
        )

    # Nếu file gửi lên vốn dĩ là audio (không cần trích xuất), dùng luôn file đó
    target_input = audio_extracted_path if os.path.exists(audio_extracted_path) else raw_video_path

    # 3. Tiếp tục đưa target_input vào Demucs
    async with gpu_lock:
        try:
            preferred_device = "cuda" if torch.cuda.is_available() else "cpu"

            async def run_demucs(device: str, shifts: int, segment: int):
                cmd = [
                    sys.executable,
                    "-m",
                    "demucs.separate",
                    "-n",
                    "htdemucs",
                    "--two-stems",
                    "vocals",
                    "--segment",
                    str(segment),
                    "--shifts",
                    str(shifts),
                    "--jobs",
                    "1",
                    "--device",
                    device,
                    "-o",
                    output_dir,
                    target_input,
                ]
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                stdout, stderr = await process.communicate()
                output = "\n".join(
                    part.decode("utf-8", errors="replace")
                    for part in (stdout, stderr)
                    if part
                )
                return process.returncode, output

            return_code, output = await run_demucs(
                preferred_device,
                shifts=2 if preferred_device == "cuda" else 1,
                segment=7,
            )

            # CUDA/PyTorch native crashes on Windows can return 0xC0000409.
            if return_code != 0 and preferred_device == "cuda":
                return_code, output = await run_demucs("cpu", shifts=0, segment=4)

            if return_code != 0:
                raise HTTPException(
                    status_code=500,
                    detail=f"Demucs failed with exit code {return_code}: {output[-8000:]}",
                )

            # 4. Tự động tìm file vocals trong output_dir (không lo lệch tên thư mục)
            vocal_path = None
            for root, dirs, files in os.walk(output_dir):
                for f in files:
                    if f.startswith("vocals"):
                        vocal_path = os.path.join(root, f)
                        break
                if vocal_path:
                    break

            if not vocal_path or not os.path.exists(vocal_path):
                raise HTTPException(status_code=500, detail="Không tìm thấy file vocal xuất ra.")

            # Chuyển vocal sang 16kHz mono: nhẹ hơn ~5 lần, Google STT khuyên dùng định dạng này
            small_path = os.path.join(task_dir, "vocals_16k_mono.wav")
            conv = subprocess.run(
                ["ffmpeg", "-y", "-i", vocal_path, "-ac", "1", "-ar", "16000",
                 "-acodec", "pcm_s16le", small_path],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            if conv.returncode == 0 and os.path.exists(small_path):
                vocal_path = small_path

            # Trả file vocal về cho Spring Boot
            return FileResponse(
                vocal_path,
                media_type="audio/wav",
                filename="vocals.wav"
            )

        finally:
            # Thu hồi VRAM tạm sau khi chạy xong
            if torch.cuda.is_available():
                torch.cuda.empty_cache()

# ---------------------------------------------------------------------------
# Tải video từ YouTube (yt-dlp) để backend upload lên Cloudinary
# ---------------------------------------------------------------------------
YOUTUBE_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"}
MAX_YOUTUBE_SECONDS = int(os.getenv("MAX_YOUTUBE_SECONDS", "600"))
# Cloudinary gói free giới hạn video 100MB / file.
MAX_YOUTUBE_BYTES = int(os.getenv("MAX_YOUTUBE_BYTES", str(95 * 1024 * 1024)))


class YoutubeDownloadRequest(BaseModel):
    url: str
    max_duration: int | None = None


def _ensure_yt_dlp():
    try:
        import yt_dlp
        return yt_dlp
    except ModuleNotFoundError:
        import site
        extra_paths = [site.getusersitepackages(), *site.getsitepackages()]
        local_app = os.environ.get('LOCALAPPDATA', '')
        if local_app:
            import glob
            extra_paths.extend(glob.glob(os.path.join(
                local_app, 'Packages', 'PythonSoftwareFoundation.Python*',
                'LocalCache', 'local-packages', 'Python*', 'site-packages'
            )))
        for candidate in extra_paths:
            if candidate and os.path.isdir(candidate) and candidate not in sys.path:
                sys.path.append(candidate)
        try:
            import yt_dlp
            return yt_dlp
        except ModuleNotFoundError:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-U', 'yt-dlp'])
            import importlib
            importlib.invalidate_caches()
            import yt_dlp
            return yt_dlp


def _download_youtube(url: str, task_dir: str, max_duration: int):
    yt_dlp = _ensure_yt_dlp()

    base_opts = {"quiet": True, "no_warnings": True, "noplaylist": True}
    with yt_dlp.YoutubeDL({**base_opts, "skip_download": True}) as ydl:
        info = ydl.extract_info(url, download=False)

    if info.get("is_live"):
        raise HTTPException(status_code=400, detail="Không hỗ trợ video đang phát trực tiếp.")
    duration = int(info.get("duration") or 0)
    if duration <= 0:
        raise HTTPException(status_code=400, detail="Không xác định được thời lượng video.")
    if duration > max_duration:
        raise HTTPException(
            status_code=400,
            detail=f"Video dài {duration // 60} phút {duration % 60} giây, tối đa {max_duration // 60} phút.",
        )

    # Ưu tiên 720p; file quá nặng thì hạ chất lượng.
    for height in (720, 480, 360):
        prefix = f"video_{height}"
        opts = {
            **base_opts,
            "format": (
                f"bv*[height<={height}][ext=mp4]+ba[ext=m4a]/"
                f"b[height<={height}][ext=mp4]/"
                f"bv*[height<={height}]+ba/b[height<={height}]"
            ),
            "merge_output_format": "mp4",
            "outtmpl": os.path.join(task_dir, prefix + ".%(ext)s"),
        }
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])

        files = [f for f in os.listdir(task_dir) if f.startswith(prefix + ".")]
        if not files:
            continue
        path = os.path.join(task_dir, files[0])
        if os.path.getsize(path) <= MAX_YOUTUBE_BYTES:
            return info, path
        os.remove(path)

    raise HTTPException(status_code=413, detail="Video quá nặng, hãy chọn video ngắn hơn.")


@app.post("/api/v1/youtube/download")
async def download_youtube(req: YoutubeDownloadRequest):
    url = req.url.strip()
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or (parsed.hostname or "").lower() not in YOUTUBE_HOSTS:
        raise HTTPException(status_code=400, detail="Link YouTube không hợp lệ.")

    max_duration = min(req.max_duration or MAX_YOUTUBE_SECONDS, MAX_YOUTUBE_SECONDS)
    task_dir = os.path.join(BASE_TEMP_DIR, "yt-" + str(uuid.uuid4()))
    os.makedirs(task_dir, exist_ok=True)

    try:
        info, path = await asyncio.to_thread(_download_youtube, url, task_dir, max_duration)
    except HTTPException:
        shutil.rmtree(task_dir, ignore_errors=True)
        raise
    except Exception as e:
        shutil.rmtree(task_dir, ignore_errors=True)
        raise HTTPException(status_code=422, detail=f"Không tải được video YouTube: {e}")

    headers = {
        "X-Video-Title": quote(info.get("title") or "youtube-video"),
        "X-Video-Duration": str(int(info.get("duration") or 0)),
        "X-Video-Id": str(info.get("id") or ""),
    }
    return FileResponse(
        path,
        media_type="video/mp4",
        filename="youtube.mp4",
        headers=headers,
        background=BackgroundTask(shutil.rmtree, task_dir, True),
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)
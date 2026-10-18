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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)
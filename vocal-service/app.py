import os
import shutil
import uuid
import torch
import asyncio
import subprocess
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse

app = FastAPI(title="Demucs Vocal Isolator Service")

# Lock để đảm bảo card 4GB VRAM chỉ chạy 1 task một lúc (tránh OOM)
gpu_lock = asyncio.Lock()

BASE_TEMP_DIR = "temp_processing"
os.makedirs(BASE_TEMP_DIR, exist_ok=True)

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
    subprocess.run(ffmpeg_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Nếu file gửi lên vốn dĩ là audio (không cần trích xuất), dùng luôn file đó
    target_input = audio_extracted_path if os.path.exists(audio_extracted_path) else raw_video_path

    # 3. Tiếp tục đưa target_input vào Demucs
    async with gpu_lock:
        try:
            device = "cuda" if torch.cuda.is_available() else "cpu"
            cmd = (
                f"demucs -n htdemucs --two-stems vocals "
                f"--segment 7 --shifts 2 --device {device} "
                f"-o \"{output_dir}\" \"{target_input}\""
            )

            # Chạy subprocess bất đồng bộ
            process = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                raise HTTPException(
                    status_code=500, 
                    detail=f"Demucs failed: {stderr.decode()}"
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

@app.on_event("shutdown")
def cleanup_temp():
    if os.path.exists(BASE_TEMP_DIR):
        shutil.rmtree(BASE_TEMP_DIR, ignore_errors=True)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)
import os
import shutil
import uuid
import torch
import asyncio
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

    input_path = os.path.join(task_dir, file.filename)
    output_dir = os.path.join(task_dir, "output")

    # Lưu file gửi từ Spring Boot
    with open(input_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Chờ GPU rảnh để xử lý
    async with gpu_lock:
        try:
            # Lệnh chạy Demucs tối ưu cho GPU 4GB
            # -n htdemucs: Model nhẹ, chất lượng cao
            # --two-stems vocals: Chỉ bóc tách vocal (tiết kiệm 50% thời gian)
            # --segment 10: Chia nhỏ audio để VRAM chỉ tốn ~1.5 - 2GB
            # --mp3: Xuất file mp3 nhẹ
            device = "cuda" if torch.cuda.is_available() else "cpu"
            cmd = (
                f"demucs -n htdemucs --two-stems vocals "
                f"--shifts 2 --segment 7 --device {device} "
                f"-o \"{output_dir}\" \"{input_path}\""
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

            # File vocal xuất ra nằm tại: output/htdemucs/{tên_file_không_đuôi}/vocals.mp3
            file_stem = os.path.splitext(file.filename)[0]
            vocal_path = os.path.join(output_dir, "htdemucs", file_stem, "vocals.wav")

            if not os.path.exists(vocal_path):
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
    # Chạy trên port 8000
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=False)
# live.py as a Hugging Face Docker Space: the shared vision service every account without a farm PC uses.
# Free CPU Spaces have 2 vCPU and 16 GB, enough for the detector, and do not sleep while they are visited.
FROM python:3.13-slim

# OpenCV (pulled in by ultralytics) needs these shared libraries even when no window is opened.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Spaces run the container as user 1000.
RUN useradd -m -u 1000 user
WORKDIR /app
# CPU-only PyTorch first: the default wheel bundles CUDA and is several GB.
RUN pip install --no-cache-dir torch==2.14.1 torchvision --index-url https://download.pytorch.org/whl/cpu
COPY requirements.txt constraints.txt ./
RUN pip install --no-cache-dir -c constraints.txt -r requirements.txt

COPY --chown=user smartcattle_ai smartcattle_ai
COPY --chown=user live.py .
COPY --chown=user models/cattle_coco_yolo11n_best.pt models/
USER user

# SPACE_HOST, set by Hugging Face, becomes the public address reported to the backend.
ENV PYTHONUNBUFFERED=1 \
    HOME=/home/user \
    YOLO_CONFIG_DIR=/tmp/ultralytics \
    SMARTCATTLE_DEVICE=cpu \
    OMP_NUM_THREADS=2 \
    MALLOC_ARENA_MAX=2 \
    SMARTCATTLE_LIVE_HOST=0.0.0.0 \
    SMARTCATTLE_LIVE_PORT=7860 \
    SMARTCATTLE_CLOUD=1 \
    SMARTCATTLE_IMGSZ=416 \
    SMARTCATTLE_MAX_CAMERAS=8 \
    SMARTCATTLE_BACKEND_URL=https://smartcattle2-backend.onrender.com \
    SMARTCATTLE_LIVE_ORIGINS=https://smartcattle2-frontend.onrender.com
EXPOSE 7860
CMD ["python", "live.py"]

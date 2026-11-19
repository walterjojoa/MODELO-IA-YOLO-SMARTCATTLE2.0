---
title: SmartCattle IA
emoji: 🐄
colorFrom: green
colorTo: yellow
sdk: docker
app_port: 7860
pinned: false
short_description: Servicio de visión de SmartCattle (YOLO) para todas las cuentas
---

# SmartCattle IA

`live.py` del repo [MODELO-IA-YOLO-SMARTCATTLE2.0](https://github.com/walterjojoa/MODELO-IA-YOLO-SMARTCATTLE2.0)
corriendo como servicio compartido: los celulares y webcams de cualquier cuenta le envían sus imágenes desde el
panel, y abre cámaras con dirección pública. Le dice al backend dónde está cada 30 s.

Este Space se publica con `scripts/publish_hf_space.sh`; no se edita a mano.

Secreto necesario en *Settings → Variables and secrets*: `SMARTCATTLE_API_KEY` = `AI_API_KEY` del backend en Render.

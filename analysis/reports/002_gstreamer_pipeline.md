# Informe Forense REA 002: Pipelines GStreamer en `libgstreamer-appcast.so`

## Resumen Ejecutivo
Auditoría de cadenas de configuración y pipelines de GStreamer / RTP / SRTP embebidas en la biblioteca ELF `lib/arm64-v8a/libgstreamer-appcast.so`.

## Cadenas de Pipelines Observadas en Binario

### 1. Pipeline H.264 RTP Sin Encriptación (Video Cleartext)
- **Offset**: `0x000030A9` y `0x0000378B`
- **Texto Exacto**:
  `appsrc name=sourceV ! queue ! rtph264pay name=rtpVpay ! udpsink host=%s port=%d`

### 2. Pipeline H.264 SRTP Encriptado (Video Secure)
- **Offset**: `0x000034FB`
- **Texto Exacto**:
  `appsrc name=sourceV ! queue ! rtph264pay name=rtpVpay ! srtpenc name=srtpV ! udpsink host=%s port=%d`

### 3. Pipeline A/V Combinado (Video H.264 + Audio AAC SRTP)
- **Offset**: `0x0000401A`
- **Texto Exacto**:
  `appsrc name=sourceV ! queue ! rtph264pay name=rtpVpay ! srtpenc name=srtpV ! queue ! udpsink host=%s port=%d  appsrc name=sourceA ! queue ! rtpmp4apay name=rtpApay ! srtpenc name=srtpA ! queue ! udpsink host=%s port=%d`

### 4. Pipeline Audio Opus SRTP
- **Offset**: `0x00003351`
- **Texto Exacto**:
  `appsrc name=sourceA ! queue ! rawaudioparse format=pcm pcm-format=s16le sample-rate=48000 num-channels=1 ! audioconvert ! opusenc ! queue ! rtpopuspay name=rtpApay ! srtpenc name=srtpA ! udpsink host=%s port=%d`

## Funciones C e Invocaciones de Inyección de Datos
- **Punto de Inyección**: `gst_native_send_data` (RVA `0x00008748`, Offset `0x00008748`)
- **Invocación Interna**: `rtpSendData` (RVA `0x00009E78`, Offset `0x00009E78`)
- **Flujo de Ejecución en C**:
  1. `gst_buffer_map` (Offset `0x000019E6`) -> Mapea el arreglo de bytes `byte[]` en memoria de GStreamer.
  2. `push-buffer` (Offset `0x00003CA4`) -> Dispara el signal en el elemento `appsrc` (`sourceV`).
  3. `gst_buffer_unmap` (Offset `0x00001A01`) -> Desmapea el buffer.

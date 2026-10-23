# Informe Forense REA 003: Método `RTPStreaming.open()` y Transporte RTP

## Resumen Ejecutivo
Auditoría del método Java `RTPStreaming.open()` en `classes15.dex` de `LG ThinQ.apk` que configura e inicia la transmisión hacia la TV LG webOS.

## Bytecode DEX Observado (`classes15.dex`)

- **Clase**: `com.connectsdk.service.webos.lgcast.common.streaming.RTPStreaming`
- **Método**: `open(android.content.Context context, long ssrc, java.lang.String ip, int videoPort, int audioPort)`
- **Instrucción Log Inicial** (Offset `4260e8`):
  `const-string v1, "open (ssrc=%d, ip=%s, videoPort=%d, audioPort=%d)"`

### Invocaciones Secuenciales a `RTPStreamer` en `open()`:

1. **Inicialización**:
   - Offset `42611a`: `invoke-virtual {v0, v4}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.initialize:(Landroid/content/Context;)V`

2. **Modo de Stream**:
   - Offset `42612c`: `invoke-virtual {v4, v0, v1, v5, v6}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.setStreamMode:(Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerData$ProtocolType;Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerData$MediaType;J)V` (pasa `ProtocolType.RTP`, `MediaType.AV`, `ssrc`)

3. **Configuración de Video**:
   - Offset `42613a`: `invoke-virtual {v4, v5}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.setVideoConfig:(Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$VideoConfig;)V`
   - Offset `426144`: `invoke-virtual {v4, v7, v8}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.setVideoDstToUri:(Ljava/lang/String;I)V` (pasa `ip` host y `videoPort`)

4. **Configuración de Audio**:
   - Offset `426152`: `invoke-virtual {v4, v5}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.setAudioConfig:(Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$AudioConfig;)V`
   - Offset `42615c`: `invoke-virtual {v4, v7, v9}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.setAudioDstToUri:(Ljava/lang/String;I)V` (pasa `ip` host y `audioPort`)

5. **Configuración de Seguridad**:
   - Offset `42616a`: `invoke-virtual {v4, v5}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.setSecurityConfig:(Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityConfig;)V` (pasa `masterKey`)

6. **Arranque del Streamer**:
   - Offset `426174`: `invoke-virtual {v4}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer;.start:()Z`

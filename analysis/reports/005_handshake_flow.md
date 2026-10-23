# Informe Forense REA 005: Cadena Completa de Handshake LGCast y HELLO

## Resumen Ejecutivo
Auditoría del flujo completo de conexión, intercambio de claves, handshake HELLO y negociación de parámetros de sesión entre la aplicación móvil LG ThinQ y la TV LG webOS.

## Cadena de Invocación Completa Verificada en DEX

```
[1. Generación de Claves]
MasterKeyFactoryIF.createKeys(publicKey)
    └──> Retorna ArrayList<MasterKey> (key, mki)

[2. Empaquetado de Capacidades]
MirroringServiceFunc.createMirroringSourceCapability(...)
    └──> Asigna masterKeys, videoCodec, videoOrientation, audioCodec, audioStreamMuxConfig, uibcEnabled
    └──> Genera JSONObject con la clave pública y parámetros del emisor

[3. Transmisión Handshake / HELLO a TV via WebSocket]
ConnectionManager.updateSourceDeviceCapability(JSONObject)
    └──> LGCastCommand.sendGetParameterResponse(...)
    └──> Transmite mensaje WebSocket LGCast / Hello a la TV LG webOS

[4. Recepción de Confirmación de TV]
WebSocket LGCast (TV Response)
    └──> Retorna: host (IP), videoPort, audioPort, ssrc

[5. Configuración de Sesión RTP]
RTPStreaming.open(Context, ssrc, host, videoPort, audioPort)
    └──> RTPStreamer.initialize(Context)
    └──> RTPStreamer.setStreamMode(RTP, AV, ssrc)
    └──> RTPStreamer.setVideoConfig(VideoConfig)
    └──> RTPStreamer.setVideoDstToUri(host, videoPort)
    └──> RTPStreamer.setAudioConfig(AudioConfig)
    └──> RTPStreamer.setAudioDstToUri(host, audioPort)
    └──> RTPStreamer.setSecurityConfig(SecurityConfig)
    └──> RTPStreamer.start()

[6. Transporte de Frames de Video]
MediaData (pts, data)
    └──> RTPStreaming$1.handleMessage(msg)
    │        ├── pts = pts * 11111
    │        └── data = MediaData.data
    └──> RTPStreamer.sendData(MediaType.VIDEO, pts * 11111, data)
            └──> RTPStreamer.nativeSendRawData(type, pts, data) [JNI]
                    └──> gst_native_send_data(...) [libgstreamer-appcast.so]
                            └──> rtpSendData(...) -> gst_buffer_map -> push-buffer -> gst_buffer_unmap
```

## Evidencia DEX de `ConnectionManager` y `LGCastCommand`
- **`ConnectionManager.updateSourceDeviceCapability`**: Offset `43138e` (Line 1189684) en `classes15.dex`
- **`LGCastCommand.sendGetParameterResponse`**: Offset `4246cc` (Line 1167128) en `classes15.dex`

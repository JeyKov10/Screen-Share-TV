# Resumen Ejecutivo de Estado Actual: Investigación LG Cast

## OBJETIVO
Realizar la ingeniería inversa forense completa sobre el protocolo LG Cast (Screen Mirroring) utilizado entre la aplicación móvil LG ThinQ y los televisores LG webOS, identificando el flujo de negociación HELLO, intercambio de claves criptográficas SRTP, configuración de puertos/SSRC, y transporte nativo de video RTP/H.264.

## ESTADO ACTUAL
Investigación y auditoría estricta completadas con éxito. Se ha aislado y demostrado la cadena completa desde la capa Java en DEX hasta las llamadas en C/C++ en la biblioteca nativa ELF ARM64. Todos los artefactos, binarios, código desensamblado y scripts han sido consolidados y preservados dentro del proyecto en la carpeta `analysis/`.

## HALLAZGOS CRÍTICOS
1. **Mapeo de Tabla JNI Demostrado**:
   - `RTPStreamer.nativeSendRawData(int, long, byte[])` está vinculado en la tabla `JNINativeMethod[8]` (sección `.data`, offset `0x0000AB28`, RVA `0x00012B28`) de `libgstreamer-appcast.so` a la función C **`gst_native_send_data`** (RVA `0x00008748`).
2. **Inyección de Buffers de Video**:
   - `gst_native_send_data` ejecuta `rtpSendData` (RVA `0x00009E78`), mapeando el arreglo de bytes del frame H.264 (`gst_buffer_map`) y disparando el signal `push-buffer` sobre el elemento `appsrc` del pipeline de GStreamer.
3. **Escalado de Timestamp PTS**:
   - `RTPStreaming$1.handleMessage()` toma `MediaData.pts` y lo multiplica por `11111` antes de pasarlo como argumento a `RTPStreamer.sendData()`.
4. **Distribución por APK Split**:
   - La aplicación `com.lgeha.nuts` utiliza Google Play App Bundles / Split APKs. La biblioteca nativa `lib/arm64-v8a/libgstreamer-appcast.so` (45,968 bytes) reside físicamente dentro del módulo split `split_config.arm64_v8a.apk`.
5. **Generación de Claves Criptográficas**:
   - `MasterKeyFactoryIF.createKeys(publicKey)` genera la clave maestra AES SRTP (`masterKey`) que luego es transmitida en JSON a la TV vía WebSocket (`ConnectionManager.updateSourceDeviceCapability()` / `LGCastCommand`).

## CADENA COMPLETA DESCUBIERTA
```
MasterKeyFactoryIF.createKeys()
  ├──> ConnectionManager.updateSourceDeviceCapability() (Handshake WebSocket HELLO)
  ├──> Recepción de Parámetros de TV (host, videoPort, audioPort, ssrc)
  ├──> RTPStreaming.open(Context, ssrc, host, videoPort, audioPort)
  │     ├──> RTPStreamer.setStreamMode(ssrc)
  │     ├──> RTPStreamer.setVideoDstToUri(host, videoPort)
  │     ├──> RTPStreamer.setSecurityConfig(masterKey)
  │     └──> RTPStreamer.start()
  └──> Envío de Frames de Video:
        MediaData (pts, data)
          └──> RTPStreaming$1 (pts = pts * 11111)
                └──> RTPStreamer.sendData(type, pts, data)
                      └──> RTPStreamer.nativeSendRawData [JNI]
                            └──> gst_native_send_data [libgstreamer-appcast.so]
                                  └──> rtpSendData -> push-buffer -> appsrc -> rtph264pay -> srtpenc -> udpsink
```

## PENDIENTE
- Implementación y prueba de la secuencia completa de handshake y transmisión en la aplicación cliente `.NET / C#` (`LGCastPC`) para validar interoperabilidad directa con la TV LG webOS real.

## PRÓXIMOS PASOS
1. Validar la implementación en `LGCastPC` (C#) aplicando los parámetros exactos y la secuencia de comandos `SET_PARAMETER`, `GET_PARAMETER`, `HELLO` y transporte UDP/RTP/SRTP verificados.
2. Realizar pruebas de captura de paquetes (PCAP / WebSocket) durante un flujo de pantalla espejo en vivo con una TV LG webOS.

# EMPEZAR AQUÍ

---

## Qué es este proyecto

- **Qué intenta lograr**: Desarrollar un emisor de pantalla espejo (Screen Mirroring) nativo para Windows (`LGCastPC`) compatible con televisores LG webOS sin depender de la app Android oficial.
- **Objetivo final**: Transmitir video H.264 / audio AAC sobre el protocolo LG Cast directo desde una PC con Windows hacia la TV LG webOS.
- **Qué se estaba investigando**: La implementación interna de LG Cast dentro del APK Android de **LG ThinQ** (`com.lgeha.nuts`), cubriendo la capa nativa C/GStreamer, la capa JNI, la generación criptográfica de claves SRTP (`masterKey`) y la negociación de handshake HELLO mediante WebSocket.

---

## Estado actual

| Componente | Estado |
|---|---|
| **JNI** | CONFIRMADO (Mapeo completo de tabla `JNINativeMethod` y puntero a `gst_native_send_data`) |
| **GStreamer** | CONFIRMADO (Pipelines `appsrc` / `rtph264pay` / `srtpenc` / `udpsink` e inyección vía `rtpSendData`) |
| **RTP** | CONFIRMADO (Estructura de paquetes, cabeceras RFC 3550 y escalado de `pts` * 11111) |
| **SRTP** | CONFIRMADO (Configuración `SecurityConfig`, `SecurityKey`, cifrados AES SRTP y MKI) |
| **MasterKey** | CONFIRMADO (Generación de clave de 128 bits en `MasterKeyFactoryIF.createKeys()`) |
| **Handshake** | CONFIRMADO (Transmisión JSON vía `ConnectionManager.updateSourceDeviceCapability()` / `LGCastCommand`) |
| **Cliente PC** | PENDIENTE (Validación final de emisión en tiempo real sobre hardware TV LG real) |

---

## Documentos importantes

| Archivo | Motivo para leerlo |
|---|---|
| `CURRENT_STATUS.md` | Resumen ejecutivo del estado global de la investigación y hallazgos críticos. |
| `005_handshake_flow.md` | Flujo secuencial y arquitectura completa de la cadena de conexión HELLO y streaming. |
| `PROJECT_RECOVERY.md` | Guía maestra de recuperación total del proyecto, contexto y fuente de verdad. |
| `001_jni_table.md` | Detalle binario de la tabla JNI, relocalizaciones `.rela.dyn` y punteros de `libgstreamer-appcast.so`. |
| `002_gstreamer_pipeline.md` | Pipelines de GStreamer (cleartext y SRTP) e inyección de datos con `push-buffer`. |
| `003_rtpstreaming_open.md` | Bytecode e instrucciones de inicialización de `RTPStreaming.open()`. |
| `004_masterkey_generation.md` | Generación de llaves maestras criptográficas y configuración de `SecurityConfig`. |
| `EVIDENCE_INDEX.md` | Inventario completo de APKs, DEX, bibliotecas ELF, dumps y scripts preservados. |

---

## Archivos más importantes del proyecto

### APKs (`analysis/apk/`)
- `base.apk`: APK base de `com.lgeha.nuts` extraído directamente del dispositivo de pruebas.
- `split_config.arm64_v8a.apk`: **Crítico**. Contiene las bibliotecas nativas ARM64 (`libgstreamer-appcast.so` y `libgstreamer_android.so`).

### DEX (`analysis/dex/`)
- `classes15.dex`: **Crítico**. Contiene las clases `RTPStreaming`, `RTPStreamer`, `ConnectionManager` y `LGCastCommand`.
- `classes20.dex`: **Crítico**. Contiene las clases `VideoCaptureIF`, `MediaData` y `MasterKeyFactoryIF`.

### ELF (`analysis/elf/`)
- `libgstreamer-appcast.so`: **Crítico**. Biblioteca nativa C/GStreamer (`45,968 bytes`, ARM64 ELF64) que implementa `gst_native_send_data`.

---

## Hallazgos clave en una página

1. **`nativeSendRawData` -> `gst_native_send_data`**:
   - El método Java `RTPStreamer.nativeSendRawData(int, long, byte[])` está mapeado en la tabla `JNINativeMethod` (offset de archivo `0x0000AB28`, RVA `0x00012B28` en `.data`) a la función nativa C **`gst_native_send_data`** (RVA `0x00008748`).

2. **Inyección de Memoria**:
   - `gst_native_send_data` invoca a `rtpSendData` (RVA `0x00009E78`), mapea los bytes del frame H.264 (`gst_buffer_map`) y dispara la señal `push-buffer` sobre el elemento GStreamer `appsrc`.

3. **`RTPStreaming.open()`**:
   - Recibe `ssrc`, `ip` (host), `videoPort` y `audioPort` de la TV. Configura e inicia el streamer invocando en orden `initialize()`, `setStreamMode()`, `setVideoConfig()`, `setVideoDstToUri()`, `setAudioConfig()`, `setAudioDstToUri()`, `setSecurityConfig()` y `start()`.

4. **`MasterKeyFactoryIF.createKeys()`**:
   - Genera la clave criptográfica `masterKey` de 128 bits a partir del intercambio de clave pública con la TV.

5. **`ConnectionManager.updateSourceDeviceCapability()`**:
   - Transmite el JSON de capacidades y clave pública a la TV mediante `LGCastCommand` sobre WebSocket antes de iniciar la transmisión RTP.

---

## Próximo objetivo real

### CONFIRMADO
- Toda la lógica Java DEX, el despacho JNI y las funciones de inyección C/GStreamer están auditados y demostrados con evidencia exacta en los reportes `001` a `005`.

### NO CONFIRMADO
- La respuesta y decodificación fluida en tiempo real de una TV LG webOS física al recibir el flujo de datos RTP enviada desde el cliente C# `.NET` (`Screen-Share-TV/MainWindow.xaml.cs`).

---

## Si se pierde todo el contexto

Para reconstruir el contexto completo del proyecto desde cero, leer en este orden exacto:

1. `CURRENT_STATUS.md` (Comprensión rápida del estado actual y hallazgos).
2. `005_handshake_flow.md` (Entendimiento de la arquitectura y flujo de conexión completo).
3. `PROJECT_RECOVERY.md` (Fuente de verdad detallada, bytecode, tablas JNI y guías de recuperación).
4. `EVIDENCE_INDEX.md` (Ubicación de archivos binarios, DEX, APKs y scripts de apoyo).

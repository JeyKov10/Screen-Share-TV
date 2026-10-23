# Inventario de Evidencias y Artefactos: Proyecto LG Cast

## Resumen de Estructura de Directorios

```
analysis/
├── apk/            -> Archivos APK base y splits extraídos del dispositivo
├── dex/            -> Archivos ejecutables DEX extraídos de los APKs
├── elf/            -> Bibliotecas binarias nativas ELF .so extraídas
├── ws_capture/     -> Capturas y registros de tráfico WebSocket (reservado)
├── rea_raw/        -> Dumps y desensamblados de REA / dexdump
├── prompts/        -> Prompts de auditoría e instrucciones
├── notes/          -> Scripts PowerShell .ps1 utilizados para la auditoría
└── reports/        -> Informes forenses Markdown generados
```

## Inventario de Archivos en `analysis/`

### 1. `analysis/apk/`
| Archivo | Tamaño (bytes) | Descripción | Relevancia |
|---|---|---|---|
| `LG ThinQ.apk` | 248,973,350 | APK base de la aplicación LG ThinQ distribuida en escritorio | APK base sin librerías nativas |
| `base.apk` | 248,973,350 | APK base extraído directamente desde el dispositivo `A6N7AUE6UWGE6T6D` | Reemplazo exacto del APK del sistema |
| `split_config.arm64_v8a.apk` | 81,087,467 | APK split de arquitectura `arm64-v8a` extraído vía ADB | **CRÍTICO**: Contiene `libgstreamer-appcast.so` y `libgstreamer_android.so` |
| `split_config.xxhdpi.apk` | 5,936,907 | APK split de densidad de pantalla xxhdpi | Recurso gráfico de interfaz |
| `split_hejhomenative.apk` | 1,232,534 | APK split de módulo nativo HejHome | Módulo dinámico adicional |
| `split_hejhomenative.config.arm64_v8a.apk` | 23,250,633 | APK split de configuración ARM64 para HejHome | Contiene binarios FFmpeg y cámara |
| `split_hejhomenative.config.xxhdpi.apk` | 33,482 | APK split de densidad xxhdpi para HejHome | Recurso gráfico de interfaz |

### 2. `analysis/dex/`
| Archivo | Descripción | Relevancia |
|---|---|---|
| `classes.dex` - `classes14.dex` | Módulos ejecutables Dalvik de LG ThinQ | Clases del sistema, AndroidX y librerías |
| `classes15.dex` | Módulo ejecutable Dalvik principal de LG Cast | **CRÍTICO**: Contiene `RTPStreaming`, `RTPStreamer`, `LGCastCommand`, `ConnectionManager` |
| `classes20.dex` | Módulo ejecutable Dalvik de interfaz LG Cast | **CRÍTICO**: Contiene `VideoCaptureIF`, `MediaData` |

### 3. `analysis/elf/`
| Archivo | Tamaño (bytes) | Arquitectura | Relevancia |
|---|---|---|---|
| `libgstreamer-appcast.so` | 45,968 | ARM64 (ELF64) | **CRÍTICO**: Contiene la tabla JNI y `gst_native_send_data` |
| `libqs_jni.so` | 235,304 | ARM64 (ELF64) | Módulo JNI UEI QuickSet |
| `libserial_port.so` | 9,608 | ARM64 (ELF64) | Módulo de comunicación serie |

### 4. `analysis/rea_raw/`
| Archivo | Descripción | Relevancia |
|---|---|---|
| `dex_dump.txt` | Dump completo desensamblado de `classes15.dex` por `dexdump` | Registro plano de bytecode e instrucciones DEX |
| `dex_dump20.txt` | Dump completo desensamblado de `classes20.dex` por `dexdump` | Registro plano de bytecode de interfaces |

### 5. `analysis/temp/`
| Script PS1 | Propósito y Función |
|---|---|
| `pull_and_inspect_apks.ps1` | Extracción vía ADB de los 6 APKs del paquete `com.lgeha.nuts` e inspección de `/lib/` |
| `parse_jni_table.ps1` | Parseador C# de secciones ELF, símbolos dinámicos, relocalizaciones y tabla `JNINativeMethod[8]` |
| `get_open_bytecode.ps1` | Extracción de bytecode desensamblado de `RTPStreaming.open()` |
| `get_handler_code.ps1` | Extracción de bytecode desensamblado de `RTPStreaming$1.handleMessage()` |
| `disasm_fn.ps1` | Verificación de direcciones de punteros de función JNI en `libgstreamer-appcast.so` |
| `dump_lgcast_handshake.ps1` | Búsqueda de clases y métodos de handshake LGCast en `classes15.dex` |

### 6. `analysis/reports/`
| Documento Markdown | Contenido Forense |
|---|---|
| `001_jni_table.md` | Tabla JNI real, punteros de 64 bits y relocalizaciones en `libgstreamer-appcast.so` |
| `002_gstreamer_pipeline.md` | Pipelines GStreamer, elementos `appsrc`/`rtph264pay`/`srtpenc` e inyección de datos |
| `003_rtpstreaming_open.md` | Bytecode y secuencia de invocaciones en `RTPStreaming.open()` |
| `004_masterkey_generation.md` | Flujo de generación de clave AES SRTP (`masterKey`) en `MasterKeyFactoryIF` |
| `005_handshake_flow.md` | Diagrama y flujo completo de negociación HELLO / WebSocket LGCast |
| `CURRENT_STATUS.md` | Resumen ejecutivo, estado actual y próximos pasos |
| `EVIDENCE_INDEX.md` | Inventario completo de artefactos y archivos preservados |

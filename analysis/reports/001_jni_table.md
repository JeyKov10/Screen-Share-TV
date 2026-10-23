# Informe Forense REA 001: Tabla JNI de `libgstreamer-appcast.so`

## Resumen Ejecutivo
Auditoría binaria estricta sobre la biblioteca ELF `lib/arm64-v8a/libgstreamer-appcast.so` (extraída de `split_config.arm64_v8a.apk`, tamaño: `45,968 bytes`, SHA-256: `1fef13eef46dfd88f8d9fa7bfbfd4fb813470774a3f3ca7737c35bdca393c5d8`).

Se demuestra la existencia y mapeo irrefutable de la tabla `JNINativeMethod[8]` inicializada dinámicamente mediante `RegisterNatives` durante la ejecución de `JNI_OnLoad`.

## Evidencia Binaria
- **Clase Java Asociada**: `com/connectsdk/service/webos/lgcast/common/transfer/RTPStreamer` (Offset RVA `0x00002CF8`)
- **Punto de Entrada JNI**: `JNI_OnLoad` (RVA `0x000083C4`, Offset de archivo `0x000083C4`, Tamaño `0xE4` bytes)
- **Ubicación de Tabla JNI en ELF**: Sección `.data` (RVA `0x00012AC8` - `0x00012B88`, Offset en archivo `0x0000AAC8` - `0x0000AB88`)
- **Tipo de Relocalización ELF**: `R_AARCH64_RELATIVE` (Tipo `1027` en `.rela.dyn`)

## Estructura de la Tabla JNI (`JNINativeMethod[8]`)
Cada entrada contiene 24 bytes (3 punteros de 64 bits: `name_ptr`, `sig_ptr`, `fnPtr`).

| Índice | Offset Archivo | Nombre JNI (`name_ptr`) | Firma JNI (`sig_ptr`) | Puntero Función (`fnPtr`) | Función C Implementadora |
|---|---|---|---|---|---|
| [0] | `0x0000AAC8` | RVA `0x00003A6D` ("nativeInit") | RVA `0x00002E38` ("()V") | RVA `0x000084BC` | `initRTPServer` |
| [1] | `0x0000AAE0` | RVA `0x00004156` ("nativeFinalize") | RVA `0x00002E38` ("()V") | RVA `0x0000853C` | `gst_native_finalize` |
| [2] | `0x0000AAF8` | RVA `0x0000384E` ("nativeClassInit") | RVA `0x0000385E` ("()Z") | RVA `0x000085F0` | `gst_native_class_init` |
| [3] | `0x0000AB10` | RVA `0x00003D81` ("nativeStart") | RVA `0x0000385E` ("()Z") | RVA `0x000086CC` | `gst_native_start` |
| **[4]** | **`0x0000AB28`** | **RVA `0x000036C4` ("nativeSendRawData")** | **RVA `0x00004707` ("(IJ[B)Z")** | **RVA `0x00008748`** | **`gst_native_send_data`** |
| [5] | `0x0000AB40` | RVA `0x00003B8B` ("nativeStop") | RVA `0x0000385E` ("()Z") | RVA `0x0000891C` | `gst_native_stop` |
| [6] | `0x0000AB58` | RVA `0x00002F87` ("nativeUpdateMasterKey") | RVA `0x00002E38` ("()V") | RVA `0x00008A68` | `updateRTPMasterKey` |
| [7] | `0x0000AB70` | RVA `0x000036D6` ("nativeSetStreamInfo") | RVA `0x00003BC1` ("(...)V") | RVA `0x00008A98` | `gst_native_set_stream_info` |

## Detalle de `nativeSendRawData`
- **Slot de Nombre**: RVA `0x00012B28` -> apuntador a RVA `0x000036C4` (`"nativeSendRawData"`)
- **Slot de Firma**: RVA `0x00012B30` -> apuntador a RVA `0x00004707` (`"(IJ[B)Z"`)
- **Slot de Función**: RVA `0x00012B38` -> apuntador al código de función C RVA `0x00008748` (`gst_native_send_data`)

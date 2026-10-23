# Plan de Acción Directo: Obtención del Primer Frame Visible en la TV

---

## 1. Lista Exacta de Cambios en la Secuencia de Conexión

Para que la TV acepte la sesión de LGCast y abra la superficie de renderizado, la secuencia enviada por WebSocket a `ssap://com.webos.service.appcasting/sendCommand` debe ser:

1. **Paso 1: `CONNECT`**
   - Transmitir comando de inicio de servicio con `service: "ScreenShare"`.
2. **Paso 2: `SET_PARAMETER`**
   - Transmitir la estructura corregida de capacidades con la clave de servicio `"ScreenShare"` (reemplazando `"mirroring"`) y el bloque `deviceInfo` estandarizado.
3. **Paso 3: `PLAY`**
   - Transmitir el comando `PLAY` para habilitar el receptor UDP de la TV.

---

## 2. Funciones a Modificar (`MainWindow.xaml.cs`)

1. **`EnviarConnectAsync(string clientKey)`** [NUEVA FUNCION]:
   - Debe crearse para enviar el mensaje `CONNECT` a `ssap://com.webos.service.appcasting/sendCommand`.
2. **`EjecutarSetParameterAsync(string clientKey)`** [MODIFICAR, Línea 986]:
   - Reemplazar el generador de cadena JSON `jsonSetParam` para usar la clave `"ScreenShare"` en lugar de `"mirroring"` y poblar los campos exactos de `deviceInfo`.
3. **`ProcesarRespuestaLGCast(string json)`** [MODIFICAR, Línea 1120]:
   - Extraer `udpPort` y `ssrc` de la respuesta JSON entregada por la TV e invocar inmediatamente `IniciarRtpTestAsync()`.
4. **`IniciarRtpTestAsync()`** [MODIFICAR, Línea 1420]:
   - Sustituir la transmisión en bucle de `dummyNal` por la captura e inyección de frames H.264 reales emitidos por el codificador de video.

---

## 3. Líneas Específicas a Modificar en `MainWindow.xaml.cs`

| Función | Líneas | Cambio Requerido |
|---|---|---|
| `EjecutarSetParameterAsync` | `L993 - L1035` | Sustituir el string JSON `jsonSetParam` por la versión corregida con `"ScreenShare"` y `deviceInfo` oficial. |
| `ManejarRespuestaWebsocket` | `L880 - L920` | Agregar invocación de `EnviarConnectAsync()` previa a `EjecutarSetParameterAsync()`. |
| `IniciarRtpTestAsync` | `L1465 - L1485` | Reemplazar el arreglo estático `dummyNal` por el consumidor de la cola de NALUs H.264 codificadas en tiempo real. |

---

## 4. JSON exacto a Reemplazar en `EjecutarSetParameterAsync`

### JSON Anterior (Líneas 993-1035):
```json
{
  "cmd": "SET_PARAMETER",
  "clientKey": "...",
  "mirroring": { ... }
}
```

### JSON Reemplazo Correcto:
```json
{
  "id": 10,
  "type": "request",
  "uri": "ssap://com.webos.service.appcasting/sendCommand",
  "payload": {
    "cmd": "SET_PARAMETER",
    "ScreenShare": {
      "video": {
        "codec": "H264",
        "clockRate": 90000,
        "framerate": 30,
        "bitrate": 10000000,
        "width": 1920,
        "height": 1080,
        "activeWidth": 1920,
        "activeHeight": 1080,
        "orientation": "LANDSCAPE"
      },
      "audio": {
        "codec": "AAC",
        "clockRate": 90000,
        "frequency": 48000,
        "streamMuxConfig": "1210",
        "channels": 2
      },
      "crypto": [],
      "uibcEnabled": true,
      "supportedFeatures": {
        "screenOrientation": "PORTRAIT,LANDSCAPE"
      }
    },
    "deviceInfo": {
      "sdkVersion": "1.6.0",
      "deviceModel": "PC",
      "OSVersion": "10.0",
      "resolution": "1920x1080",
      "appId": "com.lgeha.nuts",
      "appName": "LG ThinQ",
      "appRegion": "US"
    },
    "clientKey": "<clientKey>"
  }
}
```

---

## 5. Sustitución de `dummyNal` por Video H.264 Real

En la función `IniciarRtpTestAsync()`, el bucle de prueba emite actualmente:
```csharp
byte[] dummyNal = new byte[] { 0x00, 0x00, 0x00, 0x01, 0x67, ... };
```

Para mostrar una imagen real:
1. Reemplazar `dummyNal` por una cola concurrente (`BlockingCollection<byte[]> _frameQueue`).
2. El hilo de captura e ingeniería de video (FFmpeg) coloca los paquetes NALUs codificados en `_frameQueue`.
3. El bucle de transporte RTP desencadena los paquetes desde `_frameQueue`, empaqueta las cabeceras RTP (Payload Type 96, SSRC `1356955624`, secuencia incremental y timestamps incrementados a 90 kHz / 30 FPS = +3000) y los transmite al socket UDP `_rtpVideoClient`.

---

## 6. Opción Más Rápida: Comparativa de Opciones de Captura de Video

| Criterio | **FFmpeg CLI Pipeline (Recomendada)** | **Windows MediaFoundation** | **Desktop Duplication API (DXGI)** |
|---|---|---|---|
| **Facilidad de Integración** | **Muy Alta** (Lanzar proceso `ffmpeg.exe` leyendo stdout) | Media (Requiere P/Invoke COM) | Media-Baja (Requiere SharpDX / DirectX C#) |
| **Velocidad de Desarrollo** | **< 1 hora** | 4-6 horas | 3-5 horas |
| **Generación de SPS/PPS** | **Automática** (`-bsf:v h264_mp4toannexb`) | Requiere extracción manual | Requiere configuración de MFT |
| **Latencia** | Baja (~50-80 ms) | Muy Baja (~20-40 ms) | Nula (~10-20 ms) |
| **Veredicto** | **OPCIÓN MÁS RÁPIDA Y RECOMENDADA PARA EL PRIMER FRAME** | Opción para versión 2.0 | Opción para producción |

### Comando FFmpeg CLI Recomendado para C#:
```bash
ffmpeg.exe -f gdigrab -framerate 30 -i desktop -vf "scale=1920:1080" -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 30 -bf 0 -bsf:v h264_mp4toannexb -f h264 pipe:1
```

---

## 7. Estimación de Esfuerzo para el Primer Frame en Pantalla

- **Ajuste de JSON y Secuencia WebSocket (`CONNECT` + `SET_PARAMETER`)**: ~30 minutos.
- **Integración de FFmpeg Pipe para Captura H.264**: ~45 minutos.
- **Empaquetado RTP y Transmisión UDP**: ~30 minutos.
- **Prueba y Validación en Vivo con la TV**: ~30 minutos.

**Tiempo Total Estimado**: **~2.5 Horas**

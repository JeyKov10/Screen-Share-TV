# Lista de Comprobación y Requisitos para Streaming LG Cast (AppCasting)

---

## 1. Requisitos Confirmados

1. **Handshake Previo Obligatorio**: La TV no abre ningún puerto UDP receptor hasta recibir la secuencia de comandos JSON a través de WebSocket (`ssap://com.webos.service.appcasting/sendCommand`) autenticado con la `clientKey` de sesión.
2. **Declaración de Capacidades del Emisor (`Source Capability`)**: El emisor debe transmitir el JSON `SET_PARAMETER` con los bloques `video`, `audio`, `crypto`, `uibcEnabled` y `supportedFeatures`.
3. **Mantenimiento de Sesión (`KeepAlive`)**: La TV espera mensajes periódicos de `KEEPALIVE` vía WebSocket cada `keepAliveTimeout` segundos (por defecto 60 segundos) para evitar el cierre prematuro del socket.
4. **Transporte UDP Dual**: El protocolo asigna puertos UDP independientes para video (`videoPort`, por defecto 10000) y audio (`audioPort`, por defecto 10002).
5. **Aceptación de SSRC**: El identificador de fuente `ssrc` debe enviarse en las cabeceras RTP y declararse en la configuración inicial de transmisión.

---

## 2. Payload Sink Capability Esperado (Recibido desde la TV)

JSON retornado por la TV LG webOS en respuesta a la conexión/handshake:

```json
{
  "ipAddress": "<IP_TV>",
  "keepAliveTimeout": 60,
  "publicKey": "<CLAVE_PUBLICA_RSA_O_ECDH_TV>",
  "deviceInfo": {
    "type": "TV",
    "version": "webOS 6.0",
    "platform": "webOS",
    "SoC": "LM21A"
  },
  "mirroring": {
    "video": {
      "codec": "H264",
      "udpPort": 10000,
      "landscape": {
        "maxWidth": 1920,
        "maxHeight": 1080
      },
      "portrait": {
        "maxWidth": 1080,
        "maxHeight": 1920
      }
    },
    "audio": {
      "codec": "AAC",
      "udpPort": 10002
    },
    "supportedFeatures": {
      "screenOrientation": "landscape"
    },
    "displayOrientation": "landscape"
  }
}
```

---

## 3. Payload Source Capability Enviado (Enviado por el Cliente/App)

JSON transmitido en el comando `SET_PARAMETER` hacia `ssap://com.webos.service.appcasting/sendCommand`:

```json
{
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
    "crypto": [
      {
        "mki": "<bytes_mki_base64_o_hex>",
        "key": "<bytes_clave_aes_base64_o_hex>"
      }
    ],
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
```

---

## 4. RTP

- **Puertos Requeridos**: UDP puerto receptor dinámico indicado por la TV (`videoPort` y `audioPort`).
- **Protocolos Usados**: RTP / SRTP (RFC 3550 / RFC 3711).
- **Campos Relevantes**:
  - `Payload Type` (PT): Típicamente 96 para H.264 dinámico.
  - `Sequence Number`: Incremental entero por cada paquete enviado.
  - `Timestamp`: Reloj base a 90,000 Hz. En la capa Java de la app oficial, los timestamps de frames H.264 son escalados multiplicando `MediaData.pts` por `11111`.
  - `SSRC`: Identificador único de transmisión sincronizado en el handshake.

---

## 5. Audio

- **Codec Requerido**: `AAC` (o PCM `s16le` según configuración).
- **Clock Rate**: `90000` (reloj de paquetización RTP).
- **Frecuencia de Muestreo**: `48000` Hz.
- **Canales**: `2` (Estéreo).
- **Parámetros Observados**: `streamMuxConfig: "1210"`.

---

## 6. Video

- **Codec Requerido**: `H264` (Baseline o Main Profile).
- **Resolución Estándar**: `1920x1080` (Active Width: 1920, Active Height: 1080).
- **Framerate**: `30` FPS.
- **Bitrate Target**: `10000000` bps (10 Mbps).
- **Orientación**: `"LANDSCAPE"`.

---

## 7. Crypto

- **Estado**: Configurable / Opcional según flag `enableSecurity`.
- **Campos Observados**:
  - `masterKey`: Clave simétrica AES de 128 bits.
  - `mki`: Master Key Identifier de 16 bytes.
  - `cipherType`: `AES_CM_128_HMAC_SHA1_80` (Cifrado SRTP estándar).
- **Nivel de Evidencia**: Confirmado en `MirroringSourceCapability` y `RTPStreamerConfig$SecurityConfig`.

---

## 8. Bloqueadores Potenciales

1. **Falta de Negociación SSAP WebSocket (`clientKey`)**: Si no se envía primero el comando `CONNECT` y `SET_PARAMETER` vía WebSocket a `ssap://com.webos.service.appcasting/sendCommand`, la TV no abrirá los puertos UDP receptores.
2. **Incompatibilidad en la Estructura Criptográfica (`crypto`)**: Si la TV requiere encriptación SRTP activa y el arreglo `crypto` en `SET_PARAMETER` está vacío o la clave no coincide, la TV descartará los paquetes UDP recibidos.
3. **Escalado Incorrecto de Timestamps PTS**: En el APK oficial, `pts` es multiplicado por `11111`. Timestamps desordenados o desincronizados causarán que el decodificador H.264 de la TV descarte los frames.
4. **Ausencia de NALUs Críticas H.264 (SPS / PPS / IDR)**: El stream H.264 en bruto enviado sobre RTP debe incluir los bloques de parámetro de secuencia (SPS) y de imagen (PPS) antes del primer frame I-frame (IDR). Sin SPS/PPS, la TV no puede inicializar el decodificador por hardware.
5. **Formato de Orientación y Dimensiones Incompatibles**: Enviar resoluciones no soportadas o cadenas de orientación no válidas provoca la pérdida de inicialización de la superficie de renderizado en webOS.

---

## 9. MVP (Mínimo Producto Viable para Prueba Funcional)

Para lograr la primera imagen de video y audio en la TV LG webOS:

1. **WebSocket Handshake**:
   - Conectar al WebSocket `wss://<IP_TV>:3001`.
   - Enviar `CONNECT` con la `clientKey` válida.
   - Enviar `SET_PARAMETER` con el JSON de `ScreenShare` (`video`, `audio`, `crypto`, `deviceInfo`).
2. **Obtención de Puertos UDP**:
   - Extraer `videoPort` (ej. 10000) y `ssrc` de la respuesta JSON entregada por la TV.
3. **Socket UDP y Paquetización RTP**:
   - Crear un socket UDP hacia `<IP_TV>:<videoPort>`.
   - Tomar el stream H.264 codificado desde Windows (MediaFoundation / FFmpeg).
   - Empaquetar NALUs H.264 en paquetes RTP (Payload Type 96, SSRC configurado, timestamps incrementales a 90 kHz).
   - Asegurar que el primer paquete incluya los NALUs SPS (type 7) y PPS (type 8) seguido de un frame IDR (type 5).

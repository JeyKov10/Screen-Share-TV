# Plan de Integración FFmpeg: Captura e Inyección H.264 para Streaming RTP

---

## 1. Archivo y Clase Objetivo a Modificar

- **Archivo**: `Screen-Share-TV/MainWindow.xaml.cs`
- **Clase**: `LGCastPC.MainWindow`
- **Métodos a Modificar / Agregar**:
  1. `IniciarRtpTestAsync()` (Sustituir `dummyNal` por la llamada al capturador real).
  2. `IniciarCapturaFFmpeg(CancellationToken token)` (Nuevo método para lanzar `ffmpeg.exe` y leer stdout `pipe:1`).
  3. `ExtraerNalusAnnexB(byte[] chunkBuffer, int bytesRead)` (Nuevo método parser de delimitadores Annex-B `00 00 00 01` / `00 00 01`).

---

## 2. Comando FFmpeg Optimizado

El comando CLI ejecutado por el proceso de C# es:

```bash
ffmpeg.exe -f gdigrab -framerate 30 -i desktop -vf "scale=1920:1080" -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 30 -bf 0 -bsf:v h264_mp4toannexb -f h264 pipe:1
```

---

## 3. Código C# Completo Listo para Copiar (`MainWindow.xaml.cs`)

A continuación se presenta el código completo que debe agregarse en `Screen-Share-TV/MainWindow.xaml.cs`:

```csharp
using System.Diagnostics;
using System.IO;
using System.Collections.Concurrent;

namespace LGCastPC
{
    public partial class MainWindow : Window
    {
        private Process _ffmpegProcess;
        private ConcurrentQueue<byte[]> _naluQueue = new ConcurrentQueue<byte[]>();

        /// <summary>
        /// Inicia el proceso nativo FFmpeg para captura de escritorio y codificación H.264 Annex-B en tiempo real.
        /// </summary>
        private void IniciarCapturaFFmpeg(CancellationToken token)
        {
            Task.Run(() =>
            {
                try
                {
                    string ffmpegPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "ffmpeg.exe");
                    if (!File.Exists(ffmpegPath))
                    {
                        ffmpegPath = "ffmpeg.exe"; // Probar si está en el PATH del sistema
                    }

                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = ffmpegPath,
                        Arguments = "-f gdigrab -framerate 30 -i desktop -vf \"scale=1920:1080\" -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 30 -bf 0 -bsf:v h264_mp4toannexb -f h264 pipe:1",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true
                    };

                    _ffmpegProcess = new Process { StartInfo = psi };
                    _ffmpegProcess.ErrorDataReceived += (s, e) => { if (!string.IsNullOrEmpty(e.Data)) Debug.WriteLine($"[FFmpeg Log]: {e.Data}"); };
                    
                    _ffmpegProcess.Start();
                    _ffmpegProcess.BeginErrorReadLine();
                    AgregarLog("🚀 Proceso FFmpeg iniciado. Leyendo stdout pipe:1...");

                    Stream stdout = _ffmpegProcess.StandardOutput.BaseStream;
                    byte[] readBuffer = new byte[65536];
                    List<byte> pendingBuffer = new List<byte>();

                    while (!token.IsCancellationRequested && !_ffmpegProcess.HasExited)
                    {
                        int bytesRead = stdout.Read(readBuffer, 0, readBuffer.Length);
                        if (bytesRead <= 0) break;

                        // Agregar bytes al buffer acumulador y procesar NALUs Annex-B
                        byte[] chunk = new byte[bytesRead];
                        Array.Copy(readBuffer, 0, chunk, 0, bytesRead);
                        ProcesarChunkNalAnnexB(chunk, pendingBuffer);
                    }
                }
                catch (Exception ex)
                {
                    AgregarLog($"❌ Error en captura FFmpeg: {ex.Message}");
                }
            }, token);
        }

        /// <summary>
        /// Parsea y separa NALUs codificadas en formato Annex-B (delimitadas por 00 00 00 01 o 00 00 01)
        /// y las coloca en la cola de envío RTP.
        /// </summary>
        private void ProcesarChunkNalAnnexB(byte[] chunk, List<byte> pendingBuffer)
        {
            pendingBuffer.AddRange(chunk);

            int searchIndex = 0;
            int lastStart = -1;

            while (searchIndex < pendingBuffer.Count - 4)
            {
                // Detectar start codes 0x00000001 o 0x000001
                if (pendingBuffer[searchIndex] == 0x00 &&
                    pendingBuffer[searchIndex + 1] == 0x00 &&
                    pendingBuffer[searchIndex + 2] == 0x00 &&
                    pendingBuffer[searchIndex + 3] == 0x01)
                {
                    if (lastStart >= 0)
                    {
                        int nalLength = searchIndex - lastStart;
                        byte[] nalu = new byte[nalLength];
                        pendingBuffer.CopyTo(lastStart, nalu, 0, nalLength);
                        _naluQueue.Enqueue(nalu);
                    }
                    lastStart = searchIndex;
                    searchIndex += 4;
                }
                else if (pendingBuffer[searchIndex] == 0x00 &&
                         pendingBuffer[searchIndex + 1] == 0x00 &&
                         pendingBuffer[searchIndex + 2] == 0x01)
                {
                    if (lastStart >= 0)
                    {
                        int nalLength = searchIndex - lastStart;
                        byte[] nalu = new byte[nalLength];
                        pendingBuffer.CopyTo(lastStart, nalu, 0, nalLength);
                        _naluQueue.Enqueue(nalu);
                    }
                    lastStart = searchIndex;
                    searchIndex += 3;
                }
                else
                {
                    searchIndex++;
                }
            }

            if (lastStart > 0)
            {
                pendingBuffer.RemoveRange(0, lastStart);
            }
        }

        /// <summary>
        /// Método sustituto en IniciarRtpTestAsync para consumir la cola de NALUs H.264 reales.
        /// </summary>
        private async Task IniciarRtpTestConVideoRealAsync()
        {
            string ipTarget = !string.IsNullOrEmpty(_tvIpAddress) ? _tvIpAddress : TxtIpTv.Text.Trim();
            if (string.IsNullOrEmpty(ipTarget) || _videoUdpPort <= 0) return;

            uint ssrc = 1356955624;
            ushort videoSeq = 0;
            uint videoTs = 0;

            _rtpVideoClient?.Close();
            _rtpVideoClient = new UdpClient();
            _rtpVideoClient.Connect(ipTarget, _videoUdpPort);

            _rtpCts?.Cancel();
            _rtpCts = new CancellationTokenSource();
            var token = _rtpCts.Token;

            // Iniciar captura FFmpeg
            IniciarCapturaFFmpeg(token);

            // Tarea de transmisión RTP consumiendo NALUs reales de la cola
            _ = Task.Run(async () =>
            {
                while (!token.IsCancellationRequested && _rtpVideoClient != null)
                {
                    if (_naluQueue.TryDequeue(out byte[] realNal))
                    {
                        try
                        {
                            byte[] rtpVideoPacket = ConstruirPaqueteRtp(payloadType: 96, sequenceNumber: videoSeq++, timestamp: videoTs, ssrc: ssrc, payloadData: realNal);
                            await _rtpVideoClient.SendAsync(rtpVideoPacket, rtpVideoPacket.Length);
                            videoTs += 3000; // Incremento a 30 FPS (90000 / 30)
                        }
                        catch { }
                    }
                    else
                    {
                        await Task.Delay(5, token);
                    }
                }
            }, token);
        }
    }
}
```

---

## 4. Cambios Mínimos para Lograr Video RTP Real

1. Copiar `ffmpeg.exe` en el directorio de salida del proyecto C# (`bin/Debug/net10.0-windows/`).
2. Copiar los métodos `IniciarCapturaFFmpeg`, `ProcesarChunkNalAnnexB` e `IniciarRtpTestConVideoRealAsync` a `MainWindow.xaml.cs`.
3. Invocar `IniciarRtpTestConVideoRealAsync()` tras la confirmación del comando `PLAY`.

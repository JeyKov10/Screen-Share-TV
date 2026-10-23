# Informe Forense REA 004: Generación de `masterKey` y Criptografía SRTP

## Resumen Ejecutivo
Auditoría del flujo de generación de claves maestras criptográficas SRTP (`masterKey`) e instanciación de configuraciones de seguridad en `classes15.dex` y `classes20.dex` de `LG ThinQ.apk`.

## Clases y Métodos Involucrados

### 1. `com.lge.lib.lgcast.iface.MasterKeyFactoryIF`
- **Método**: `createKeys(java.lang.String publicKey)` (Line 1190532, Offset `4305fa`)
  `invoke-virtual {v0, v6}, Lcom/lge/lib/lgcast/iface/MasterKeyFactoryIF;.createKeys:(Ljava/lang/String;)Ljava/util/ArrayList;`
- **Método de Claves Fijas**: `createFixedKeys(byte[] bytes)` (Line 1190655, Offset `43065c`)
- **Retorno**: Instancias de `MasterKey` compuestas por `key:[B` (clave maestra AES) y `mki:[B` (Master Key Identifier).

### 2. `com.connectsdk.service.webos.lgcast.screenmirroring.service.MirroringServiceFunc`
- **Asignación de Clave en `SecurityKey`**:
  - Offset `430460`: `iget-object v3, v1, Lcom/lge/lib/lgcast/iface/MasterKey;.key:[B`
  - Offset `430464`: `iput-object v3, v2, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityKey;.masterKey:[B`
  - Offset `430468`: `iget-object v1, v1, Lcom/lge/lib/lgcast/iface/MasterKey;.mki:[B`
  - Offset `43046c`: `iput-object v1, v2, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityKey;.mki:[B`

- **Instanciación de `SecurityConfig`**:
  - Offset `43047c`: `invoke-direct {v4}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityConfig;.<init>:()V`
  - Offset `430484`: `invoke-virtual {v4, v1}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityConfig;.setEnableSecurity:(Z)V`
  - Offset `43048e`: `invoke-virtual {v4, v1}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityConfig;.setCipherType:(SRTPCipherType)V`
  - Offset `430498`: `invoke-virtual {v4, v1}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityConfig;.setAuthType(SRTPAuthType)V`
  - Offset `43049e`: `invoke-virtual {v4, v0}, Lcom/connectsdk/service/webos/lgcast/common/transfer/RTPStreamerConfig$SecurityConfig;.setKeys:(Ljava/util/ArrayList;)V`

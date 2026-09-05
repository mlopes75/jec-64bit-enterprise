# 💎 JEC Enterprise 64-Bit — Sistema (Julia Epoch Compact)

O **Ecossistema JEC Enterprise** é uma extensão de infraestrutura de alta performance baseada no algoritmo determinístico do **Sistema Julia** original. Esta especificação foi concebida para realizar **Bit Packing** na camada de aplicação, encapsulando alta precisão temporal (**microssegundos**) e **7 bits de metadados livres** dentro de uma única palavra nativa de **64 bits (8 Bytes)**.

Este repositório é um ambiente unificado (monorepo) contendo as implementações oficiais para **Dart (Backend/Fluxos de Dados)** e **Solidity (Web3/EVM)**, garantindo persistência e transmissão cross-platform 100% simétrica.

*Dedicado em homenagem à minha filha Julia pelo tempo que nos foi tirado.*

---

## 📐 Estrutura do Barramento de Bits

```text
0             7             12            19        23        28        33        39        45                  64
[ User Space ][ Século JEC ][  Ano Puro   ][ Mês   ][  Dia   ][ Hora   ][ Minut ][ Segun ][   Microssegundos   ]
   (7 bits)      (5 bits)      (7 bits)    (4 bits)  (5 bits)  (5 bits)  (6 bits)  (6 bits)       (20 bits)
```
- User Space (7 bits): Espaço livre do utilizador para injetar o ID do microsserviço ou servidor (0 a 127) sem custo extra de armazenamento.
- Século (5 bits): Mapeado pelas 25 letras do alfabeto JEC (banindo a letra "O" para evitar ambiguidade visual).
- Ano (7 bits): Guarda o valor puro do ano corrente (0 a 99).
- Microssegundos (20 bits): Garante alta precisão (0 a 999.999) com zero erros de arredondamento.

🛡️ Implementações Oficiais🎯

1. Camada Dart (Server-Side / Flutter)Localizada na pasta /dart, esta biblioteca nativa foi desenhada com operadores binários puros para compressão extrema em microsserviços.

Exemplo de Uso:
```
Dartimport 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';

void main() {
  int payload64Bits = JecEnterprise64BitPacker.pack(
    headerBits: 42,
    seculo: "V",
    ano: 26,
    mes: 9,
    dia: 3,
    hora: 22,
    minuto: 50,
    segundo: 15,
    microssegundos: 123456,
  );

  print('ID Binário Compactado: $payload64Bits');
  
  String visualString = JecEnterprise64BitPacker.unpackToHumanString(payload64Bits, alias: "LOG");
  print('String Visual: $visualString'); // LOG.V26ICW225015.123456
}
```
2. Camada Solidity (Ethereum / EVM)Localizada na pasta /solidity, a biblioteca foi desenvolvida com foco em Gas Optimization, permitindo salvar múltiplos parâmetros de tempo gastando apenas um slot de memória (uint64).

📊 Métricas de Impacto em Larga Escala

| Formato Usado | Pegada em Memória | Eficiência vs Unix 64-bit | Espaço p/ Metadados |
| :--- | :---: | :---: | :---: |
| **ISO-8601 String** | 24 Bytes | -200% (Desperdício) | Nenhum |
| **Unix Epoch + Microssegundos** | 16 Bytes (Struct) | -100% (Desperdício) | Nenhum |
| **JEC Enterprise** | **8 Bytes (uint64)** | **+75% de Economia** | **7 bits livres inclusos** |

🧪 Testes de Stress e Integridade
Para rodar os testes automatizados da camada Dart:
```
dart pub get
dart test
```

📦 Repositórios do Ecossistemajec-sistema-julia-epoch-compact — Algoritmo base focado em representação visual e strings.jec-64bit-enterprise — Este repositório focado em arquitetura binária e Web3.

📄 LicençaEste projeto está licenciado sob a Licença MIT (Variante Ética) — consulte o arquivo LICENSE para detalhes.

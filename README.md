# 💎 JEC Enterprise 64-Bit — Sistema (Julia Epoch Compact)

O **Ecossistema JEC Enterprise** é uma extensão de infraestrutura de alta performance baseada no algoritmo determinístico do **Sistema Julia** original. Esta especificação foi concebida para realizar **Bit Packing** na camada de aplicação, encapsulando alta precisão temporal (**microssegundos**) e **6 bits de metadados livres** dentro de uma única palavra nativa de **64 bits (8 Bytes)**.

Este repositório é um ambiente unificado (monorepo) contendo as implementações oficiais para **Dart (Backend/Fluxos de Dados)** e **Solidity (Web3/EVM)**, garantindo persistência e transmissão cross-platform 100% simétrica.

*Dedicado em homenagem à minha filha Julia pelo tempo que nos foi tirado.*

---

## 📐 Estrutura do Barramento de Bits

```text
63                     58 57       53 52      46 45   42 41   37 36   32 31   26 25   20 19                  0

[ Header / User Space   ][ Século   ][ Ano     ][ Mês  ][ Dia  ][ Hora ][ Min  ][ Seg  ][ Microssegundos     ]

     (6 bits)             (5 bits)   (7 bits)    (4b)    (5b)    (5b)    (6b)    (6b)       (20 bits)
```
- User Space (6 bits): Espaço livre do utilizador para injetar o ID do microsserviço ou servidor (0 a 63) sem custo extra de armazenamento.
- Século (5 bits): Mapeado pelas 25 letras do alfabeto JEC (banindo a letra "O" para evitar ambiguidade visual).
- Ano (7 bits): Guarda o valor puro do ano corrente (0 a 99).
- Microssegundos (20 bits): Garante alta precisão (0 a 999.999) com zero erros de arredondamento.

🛡️ Implementações Oficiais

🎯 1. Camada Dart (Server-Side / Flutter)
- Localizada na pasta /dart, esta biblioteca nativa foi desenhada com operadores binários puros para compressão extrema em microsserviços.

Exemplo de Uso: - Dart
```
import 'package:jec_enterprise_64bit/jec_enterprise_64bit.dart';

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
🎯 2. Camada Solidity (Ethereum / EVM)
- Localizada na pasta /solidity, a biblioteca foi desenvolvida com foco em Gas Optimization, permitindo salvar múltiplos parâmetros de tempo gastando apenas um slot de memória (uint64).

📊 Métricas de Impacto em Larga Escala

| Formato Usado               |     Pegada em Dados    |                 Comparação Estrutural                 |   Espaço p/ Metadados   |
| :-------------------------- | :--------------------: | :---------------------------------------------------: | :---------------------: |
| **ISO-8601 String**         |      ~20–32 Bytes      |               Texto, parsing necessário               |         ❌ Nenhum        |
| **Unix Epoch (`uint64`)**   |         8 Bytes        |               Apenas timestamp absoluto               |         ❌ Nenhum        |
| **Unix + Contexto Externo** |        ≥ 9 Bytes       |             Requer armazenamento adicional            |       ⚠️ Separado       |
| **💎 JEC Enterprise**       | **8 Bytes (`uint64`)** | **Contexto + Timestamp estruturado + Microssegundos** | **✅ 6 bits integrados** |


⚡ Vantagem do JEC Enterprise: enquanto um Unix Timestamp de 64 bits utiliza todos os seus bits exclusivamente para representar um instante temporal, o JEC Enterprise utiliza os mesmos 64 bits para encapsular data estruturada, hora, precisão de microssegundos e 6 bits de metadados contextualizáveis, sem aumentar o tamanho do valor armazenado.

🧪 Testes de Stress e Integridade
Para rodar os testes automatizados da camada Dart:
```
dart pub get
dart test
```

📦 Repositórios do Ecossistema jec-sistema-julia-epoch-compact 
- Algoritmo base focado em representação visual e strings.jec-64bit-enterprise
- Este repositório focado em arquitetura binária e Web3.

📄 Licença
Este projeto está licenciado sob a Licença MIT (Variante Ética)
- consulte o arquivo LICENSE para detalhes.


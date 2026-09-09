# 💎 JEC Enterprise 64-Bit — Sistema (Julia Epoch Compact)

O **Ecossistema JEC Enterprise** é uma extensão de infraestrutura de alta performance baseada no algoritmo determinístico do **Sistema Julia** original. Esta especificação foi concebida para realizar **Bit Packing** na camada de aplicação, encapsulando alta precisão temporal (**microssegundos**) e **7 bits de metadados livres** dentro de uma única palavra nativa de **64 bits (8 Bytes)**.

Este repositório é um ambiente unificado (monorepo) contendo as implementações oficiais para **Dart (Backend/Fluxos de Dados)** e **Solidity (Web3/EVM)**, garantindo persistência e transmissão cross-platform 100% simétrica.

> ⚠️ **Nota sobre longevidade:** "O JEC assume um ciclo de 1500 anos; para diferenciar ciclos, use os bits de User Space ou mantenha contexto externo de época."
>
> 💡 **Nota sobre parsing:** A representação string do JEC é otimizada para leitura humana e memorização. Para qualquer operação automatizada (comparação, ordenação, armazenamento), use sempre o valor `uint64` binário subjacente. A string é derivada do binário, nunca o contrário.
>

### *Dedicado em homenagem à minha filha Julia pelo tempo que nos foi tirado.*

## 🎯 Problema de Design Resolvido

O JEC Enterprise foi concebido para resolver a **colisão de aliases 
em sistemas distribuídos** sem sacrificar legibilidade humana.

> **Cenário:** Dois usuários distintos, ambos chamados "João", 
> criam o alias `João.JEC` em serviços diferentes.
> 
> **Sem JEC:** Colisão garantida. Requer tabela de mapeamento 
> externa, UUIDs opacos, ou namespaces hierárquicos complexos.
> 
> **Com JEC:** `João.Z26J0Y5314.421983` vs 
> `João.Z26J0Y5314.421984` — temporalidade incorporada 
> desambigui automaticamente. Mesmo no mesmo microssegundo, 
> o header de 7 bits (ID do serviço) garante unicidade 
> cross-plataforma.

**O JEC não compete com Unix Timestamp.**
O Unix resolve "quando". O JEC resolve "quem + quando + onde, 
de forma que um humano possa ler e lembrar."

---

## 📐 Estrutura do Barramento de Bits

```text
63                     57 56       53 52      46 45   42 41   37 36   32 31   26 25   20 19                  0

[ Header / User Space   ][ Século   ][ Ano     ][ Mês  ][ Dia  ][ Hora ][ Min  ][ Seg  ][ Microssegundos     ]

     (7 bits)             (4 bits)   (7 bits)    (4b)    (5b)    (5b)    (6b)    (6b)       (20 bits)
```
- User Space (7 bits): Espaço livre do utilizador para injetar o ID do microsserviço ou servidor (0 a 127) sem custo extra de armazenamento.
- Século (4 bits): Mapeado pelas 15 letras do alfabeto JEC (banindo as letras "I" e "O" para evitar ambiguidade visual).
- Ano (7 bits): Guarda o valor puro do ano corrente (0 a 99).
- Microssegundos (20 bits): Garante alta precisão (0 a 999.999) com zero erros de arredondamento.

🛡️ Implementações Oficiais

🎯 1. Camada Dart (Server-Side / Flutter)
- Localizada na pasta /dart, esta biblioteca nativa foi desenhada com operadores binários puros para compressão extrema em microsserviços.

⏳ Especificação do Ciclo Temporal e Alfabeto Limpo

O JEC Enterprise assume um ciclo determinístico de 1500 anos de longevidade total (dividido em 15 blocos lineares de 100 anos), iniciando a sua época na letra Z no ano 2000.
= Para erradicar a ambiguidade visual clássica dos computadores, o alfabeto de suporte foi severamente limpo, banindo em definitivo as letras "O" (confundível com zero) e "I" (confundível com o número um), restando 24 letras puras:
- **[A, B, C, D, E, F, G, H, J, K, L, M, N, P, Q, R, S, T, U, V, W, X, Y, Z]**
  
🗺️ Mapeamento do Século (Ciclo de 1500 Anos)

O campo de 4 bits utiliza as primeiras 15 letras (de Z a P) para cobrir o ciclo completo:
- Z: Anos 2000 a 2099 (2026 está neste bloco)
- A até N: Séculos seguintes intercalados.
- P: Anos 3400 a 3499 (Fecho do ciclo de 1500 anos na 15ª posição)

> ### Caso Especial: Século 20 ('Y')
> O valor binário máximo de 4 bits (`1111` ou `15` em decimal) foi reservado como um **Código de Exceção** para o século 20:
> * **Código:** `1111` (`0b1111`)
> * **Representação:** Letra `Y` (Anos 1900 a 1999)

## Tabela de Correspondência de Bits do Século

| Valor Binário | Valor Decimal | Letra Correspondente | Século / Ciclo |
| :--- | :--- | :--- | :--- |
| `0000` | 0 | Z | Ciclo Padrão de 1500 anos |
| `0001` | 1 | A | Ciclo Padrão de 1500 anos |
| `0010` | 2 | B | Ciclo Padrão de 1500 anos |
| ... | ... | ... | ... |
| `1110` | 14 | P | Ciclo Padrão de 1500 anos |
| **`1111`** | **15** | **Y** | **Caso Especial: Século 20 (1900-1999)¹** |

---
*¹ **Nota de Implementação:** O valor `1111` é um código de exceção explícito. Ele é tratado isoladamente por condicionais (`if/else`) no código Dart para manter a lista do ciclo padrão puramente com 1500 anos.*


## 📅 Mapeamento Híbrido dos Dias (Segurança Visual Anticolisão)

A representação de texto do dia do mês foi reestruturada para alternar entre formatos de caracteres, garantindo que o observador saiba a fase exata do mês num único olhar:
- Dias 1 a 24 (Letras): Representados sequencialmente pelas letras do alfabeto limpo (Dia 1 = A, Dia 9 = J [pula I], Dia 24 = Z).
- Dias 25 a 31 (Números): Representados pelo último dígito numérico, omitindo a dezena (Dia 25 = 5, Dia 30 = 0, Dia 31 = 1).

| Dia | Letra | Dia | Letra | Dia | Letra | Dia | Letra |
| :-: | :---: | :-: | :---: | :-: | :---: | :-: | :---: |
| 01 | A | 07 | G | 13 | N | 19 | U |
| 02 | B | 08 | H | 14 | P | 20 | V |
| 03 | C | 09 | J | 15 | Q | 21 | W |
| 04 | D | 10 | K | 16 | R | 22 | X |
| 05 | E | 11 | L | 17 | S | 23 | Y |
| 06 | F | 12 | M | 18 | T | 24 | Z |

| Dia | Representação |
| :-: | :-----------: |
| 25 | 5 |
| 26 | 6 |
| 27 | 7 |
| 28 | 8 |
| 29 | 9 |
| 30 | 0 |
| 31 | 1 |

📅 Mapeamento Híbrido das Horas (Segurança Visual Anticolisão)

A representação de texto das horas foi reestruturada para iniciar com a letra "Z" representando a meia-noite (00:00), garantindo que o observador identifique rapidamente o período do dia num único olhar.

⚠️ Nota : Esta abordagem segue a mesma lógica de indexação utilizada nos meses e dias, onde o alfabeto limpo (sem as letras "I" e "O") é empregado para evitar ambiguidade visual com números.

Horas 00 a 23 (Letras): Representadas sequencialmente pelas letras do alfabeto limpo, iniciando em Z para a hora zero (meia-noite) e seguindo a ordem alfabética até Y para as 23 horas:

| Hora | Letra | Hora | Letra | Hora | Letra | Hora | Letra |
| :-: | :---: | :-: | :---: | :-: | :---: | :-: | :---: |
| 00 | Z | 06 | F | 12 | M | 18 | T |
| 01 | A | 07 | G | 13 | N | 19 | U |
| 02 | B | 08 | H | 14 | P | 20 | V |
| 03 | C | 09 | J | 15 | Q | 21 | W |
| 04 | D | 10 | K | 16 | R | 22 | X |
| 05 | E | 11 | L | 17 | S | 23 | Y |

Y = 23:00 (23h - última hora do dia)

## 📋 Tabela Completa de Mapeamento do Ecossistema

| Campo | Bits | Range | Mapeamento | Exemplo |
| :---- | :--: | :---- | :--------- | :------ |
| **Header/User Space** | 7 bits | 0-127 | Espaço livre do utilizador | 99 = ID do microsserviço |
| **Século** | 4 bits | 0-14 (Z-N) | Z=2000, A=2100, B=2200, C=2300, D=2400, E=2500, F=2600, G=2700, H=2800, J=2900, K=3000, L=3100, M=3200, N=3300, P=3400 | Z = 2000-2099 |
| **Ano** | 7 bits | 00-99 | Valor numérico puro | 26 = 2026 |
| **Mês** | 4 bits | 1-12 (A-M) | A=Jan, B=Fev, C=Mar, D=Abr, E=Mai, F=Jun, G=Jul, H=Ago, J=Set, K=Out, L=Nov, M=Dez | J = Setembro |
| **Dia** | 5 bits | 1-31 | 1-24=Letras (A-Z), 25-31=Números (5-1) | 0 = Dia 30 |
| **Hora** | 5 bits | 00-23 (Z-Y) | Z=00, A=01, B=02, C=03, D=04, E=05, F=06, G=07, H=08, J=09, K=10, L=11, M=12, N=13, P=14, Q=15, R=16, S=17, T=18, U=19, V=20, W=21, X=22, Y=23 | Y = 23h |
| **Minuto** | 6 bits | 00-59 | Valor numérico puro (2 dígitos) | 53 |
| **Segundo** | 6 bits | 00-59 | Valor numérico puro (2 dígitos) | 14 |
| **Microssegundo** | 20 bits | 000000-999999 | Valor numérico puro (6 dígitos) | 421983 |



🎯 Exemplo de Uso Atualizado (Camada Dart)
```
void main() {
  // Exemplo para o ano de 2026 (Século Z, Ano 26) e Dia 30
  final int packed = JecEnterprise64Bit.pack(
    headerBits: 99,     // 7 bits (0-127)
    seculo: "Z",        // Ciclo de 1500 anos (Bloco 2000-2099)
    ano: 26,
    mes: 9,             // Setembro = J (A=1, B=2, ... H=8, J=9)
    dia: 30,            // Dias 25-31 = último dígito (30 = '0')
    hora: 23,           // Hora 23 = Y (00=Z, 01=A, ... 23=Y)
    minuto: 53,
    segundo: 14,
    microssegundos: 421983,
  );

  print(JecEnterprise64Bit.unpackToHumanString(packed, alias: "LOG"));
  // Saída: "LOG.Z26J0Y5314.421983"
}
```
🎯 2. Camada Solidity (Ethereum / EVM)

- "Na EVM, um uint64 ocupa um slot de 256 bits, mas permite que múltiplos campos JEC sejam empacotados junto com outros dados no mesmo slot via bit packing manual, ou que o valor seja passado eficientemente entre funções como parâmetro de 64 bits (mais barato em calldata/memory que uint256)."

📊 Métricas de Impacto em Larga Escala

| Formato Usado               |     Pegada em Dados    |                 Comparação Estrutural                 |   Espaço p/ Metadados   |
| :-------------------------- | :--------------------: | :---------------------------------------------------: | :---------------------: |
| **ISO-8601 String**         |      ~20–32 Bytes      |               Texto, parsing necessário               |         ❌ Nenhum        |
| **Unix Epoch (`uint64`)**   |         8 Bytes        |               Apenas timestamp absoluto               |         ❌ Nenhum        |
| **Unix + Contexto Externo** |        ≥ 9 Bytes       |             Requer armazenamento adicional            |       ⚠️ Separado       |
| **💎 JEC Enterprise**       | **8 Bytes (`uint64`)** | **Contexto + Timestamp estruturado + Microssegundos** | **✅ 7 bits integrados** |


⚡ Vantagem do JEC Enterprise: enquanto um Unix Timestamp de 64 bits utiliza todos os seus bits exclusivamente para representar um instante temporal, o JEC Enterprise utiliza os mesmos 64 bits para encapsular data estruturada, hora, precisão de microssegundos e 7 bits de metadados contextualizáveis, sem aumentar o tamanho do valor armazenado.

🧪 Testes de Stress e Integridade
Para rodar os testes automatizados da camada Dart:
```
dart pub get
dart test
```
e
```
dart test test/jec_enterprise_integrity_test.dart
```
+ 📦 **Repositórios do Ecossistema**
+ - **jec-sistema-julia-epoch-compact**: Algoritmo base focado em representação visual e strings.
+ - **jec-64bit-enterprise**: Este repositório focado em arquitetura binária e Web3.

📄 Licença
Este projeto está licenciado sob a Licença MIT - consulte o arquivo LICENSE.md para detalhes.


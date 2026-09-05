# jec-64bit-enterprise
A versão JEC Enterprise 64-bit será um repositório completamente independente e focado em infraestrutura de alta performance, onde o tempo e os metadados são triturados diretamente na camada de bits (UInt64/BIGINT), gerando uma poupança física imediata de 50% de espaço em cache (RAM) e rede para grandes servidores.

# 💎 JEC Enterprise 64-Bit ⚡

Uma extensão de infraestrutura de alta performance para o ecossistema **JEC (Julia Epoch Compact)**. 

Este pacote implementa **Bit Packing** na camada de aplicação para encapsular alta precisão temporal (**microssegundos**) e **7 bits livres de contexto** dentro de uma palavra nativa de **64 bits (8 Bytes)**. Focado exclusivamente em Green Computing, redução de custos na nuvem e Big Data.

## 📊 O Impacto Arquitetural

Nos sistemas tradicionais de hiperescala, as marcas temporais com precisão de microssegundos exigem estruturas pesadas (como `struct timeval` em C) que chegam a consumir **128 bits (16 bytes)** na memória RAM e nos índices de bases de dados. 

O JEC Enterprise consolida essa pegada matemática exatamente pela metade.

| Métrica Analisada | Padrão Comum de Mercado | JEC Enterprise 64-bit | Impacto Real |
| :--- | :---: | :---: | :---: |
| **Tamanho Físico** | 16 Bytes (Estrutura estruturada) | **8 Bytes (Nativo)** | **50% de Economia** |
| **Metadados (Origem)** | Exige colunas extras (+4 Bytes) | **7 bits embutidos (Grátis)** | Custos de I/O zerados |
| **Leitura na CPU** | Parsing complexo de calendários | **Máscaras binárias nativas** | Redução do consumo térmico |

### ⚙️ Divisão Estrutural do Barramento
```text
0             6             11            18        22        27        32        38        44                   63
[ User Space ][ Século JEC ][  Ano Puro   ][ Mês   ][  Dia   ][ Hora   ][ Minut ][ Segun ][   Microssegundos   ]
   (7 bits)      (5 bits)      (7 bits)    (4 bits)  (5 bits)  (5 bits)  (6 bits)  (6 bits)       (20 bits)
```

1. **User Space (7 bits libres):** Espaço para embutir o ID do microsserviço ou servidor (0 a 127) que disparou o evento.
2. **Precisão Cirúrgica (20 bits):** Suporta até 1.000.000 de microssegundos por segundo sem arredondamentos.

## 🚀 Instalação e Testes

Adicione ao seu `pubspec.yaml`:
```yaml
dependencies:
  jec_enterprise_64bit:
    git:
      url: https://github.com
```

Para rodar a suite de testes unitários automatizados:
```bash
dart pub get
dart test
```

## 📄 Licença
Este projeto está licenciado sob a Licença MIT.

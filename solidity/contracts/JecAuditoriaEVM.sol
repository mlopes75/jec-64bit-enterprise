// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JecEnterprise64BitPacker.sol";
import "../src/JecAuditoriaEVM.sol";

contract JecAuditoriaEVMTest is Test {
    JecAuditoriaEVM public auditoria;

    function setUp() public {
        auditoria = new JecAuditoriaEVM();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TESTES DA BIBLIOTECA JecEnterprise64BitPacker
    // ═══════════════════════════════════════════════════════════════════════

    function testPackAndUnpack() public pure {
        uint64 header = 99;
        string memory seculo = "Z";
        uint64 ano = 26;
        uint64 mes = 9;
        uint64 dia = 30;
        uint64 hora = 23;
        uint64 minuto = 53;
        uint64 segundo = 14;
        uint64 micro = 421983;

        uint64 packed = JecEnterprise64BitPacker.pack(
            header, seculo, ano, mes, dia, hora, minuto, segundo, micro
        );

        (uint64 h, uint64 sIdx, uint64 a, uint64 m, uint64 d, uint64 hh, uint64 min, uint64 seg, uint64 mic) =
            JecEnterprise64BitPacker.unpack(packed);

        assertEq(h, header);
        assertEq(sIdx, 0); // Z → 0
        assertEq(a, ano);
        assertEq(m, mes);
        assertEq(d, dia);
        assertEq(hh, hora);
        assertEq(min, minuto);
        assertEq(seg, segundo);
        assertEq(mic, micro);
    }

    function testHumanString() public pure {
        uint64 packed = JecEnterprise64BitPacker.pack(
            99, "Z", 26, 9, 30, 23, 53, 14, 421983
        );
        string memory result = JecEnterprise64BitPacker.unpackToHumanString(packed, "LOG");
        assertEq(result, "LOG.Z26J0Y5314.421983");
    }

    function testHumanStringAliasVazio() public pure {
        uint64 packed = JecEnterprise64BitPacker.pack(
            0, "Z", 0, 1, 1, 0, 0, 0, 0
        );
        string memory result = JecEnterprise64BitPacker.unpackToHumanString(packed, "");
        assertEq(result, ".Z001AA0000.000000");
    }

    function testExtractHeaderBits() public pure {
        uint64 packed = JecEnterprise64BitPacker.pack(
            99, "Z", 26, 9, 30, 23, 53, 14, 421983
        );
        uint64 header = JecEnterprise64BitPacker.extractHeaderBits(packed);
        assertEq(header, 99);
    }

    // ─── Testes de validação de século ──────────────────────────────────

    function testSeculoValido() public pure {
        // Letras válidas: Z, A, B, C, D, E, F, G, H, J, K, L, M, N, P, Y
        string[16] memory validos = ["Z","A","B","C","D","E","F","G","H","J","K","L","M","N","P","Y"];
        for (uint i = 0; i < validos.length; i++) {
            // Apenas verifica que não reverte
            JecEnterprise64BitPacker.pack(0, validos[i], 0, 1, 1, 0, 0, 0, 0);
        }
    }

    function testSeculoMinusculo() public pure {
        uint64 packed = JecEnterprise64BitPacker.pack(0, "z", 0, 1, 1, 0, 0, 0, 0);
        (,, uint64 sIdx,,,,,,) = JecEnterprise64BitPacker.unpack(packed);
        assertEq(sIdx, 0); // 'z' → 'Z' → 0
    }

    function testSeculoInvalido() public {
        // String vazia
        vm.expectRevert("JEC: Seculo deve ter 1 caractere");
        JecEnterprise64BitPacker.pack(0, "", 0, 1, 1, 0, 0, 0, 0);

        // Múltiplos caracteres
        vm.expectRevert("JEC: Seculo deve ter 1 caractere");
        JecEnterprise64BitPacker.pack(0, "ZZ", 0, 1, 1, 0, 0, 0, 0);

        // Letra fora do alfabeto
        vm.expectRevert("JEC: Seculo fora do alfabeto homologado (Z-P ou Y)");
        JecEnterprise64BitPacker.pack(0, "R", 0, 1, 1, 0, 0, 0, 0);

        vm.expectRevert("JEC: Seculo fora do alfabeto homologado (Z-P ou Y)");
        JecEnterprise64BitPacker.pack(0, "I", 0, 1, 1, 0, 0, 0, 0);

        vm.expectRevert("JEC: Seculo fora do alfabeto homologado (Z-P ou Y)");
        JecEnterprise64BitPacker.pack(0, "O", 0, 1, 1, 0, 0, 0, 0);
    }

    // ─── Testes de validação de data ─────────────────────────────────────

    function testDataValida() public pure {
        // Fevereiro de ano bissexto (2000) → 29 dias
        JecEnterprise64BitPacker.pack(0, "Z", 0, 2, 29, 0, 0, 0, 0);
        // Fevereiro de ano não bissexto (2001) → 28 dias
        JecEnterprise64BitPacker.pack(0, "Z", 1, 2, 28, 0, 0, 0, 0);
        // Mês de 30 dias
        JecEnterprise64BitPacker.pack(0, "Z", 0, 4, 30, 0, 0, 0, 0);
        // Mês de 31 dias
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 31, 0, 0, 0, 0);
    }

    function testDataInvalida() public {
        // Fevereiro 30
        vm.expectRevert("JEC: Fevereiro excede limite de dias");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 2, 30, 0, 0, 0, 0);

        // Fevereiro 29 em ano não bissexto (2001)
        vm.expectRevert("JEC: Fevereiro excede limite de dias");
        JecEnterprise64BitPacker.pack(0, "Z", 1, 2, 29, 0, 0, 0, 0);

        // Mês de 30 dias com 31
        vm.expectRevert("JEC: Mes de 30 dias excedido");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 4, 31, 0, 0, 0, 0);

        // Mês de 31 dias com 32 (já é capturado pelo limite de dia 1-31)
        // Mas vamos testar um dia > 31
        vm.expectRevert("JEC: Dia invalido (1-31)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 32, 0, 0, 0, 0);
    }

    // ─── Testes de limites ──────────────────────────────────────────────

    function testLimitesValidos() public pure {
        // Header máximo (127)
        JecEnterprise64BitPacker.pack(127, "Z", 0, 1, 1, 0, 0, 0, 0);
        // Ano máximo (99)
        JecEnterprise64BitPacker.pack(0, "Z", 99, 1, 1, 0, 0, 0, 0);
        // Mês mínimo (1) e máximo (12)
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 0, 0, 0);
        JecEnterprise64BitPacker.pack(0, "Z", 0, 12, 31, 0, 0, 0, 0);
        // Dia mínimo (1) e máximo (31)
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 0, 0, 0);
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 31, 0, 0, 0, 0);
        // Hora máxima (23)
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 23, 0, 0, 0);
        // Minuto máximo (59)
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 59, 0, 0);
        // Segundo máximo (59)
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 0, 59, 0);
        // Microssegundo máximo (999999)
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 0, 0, 999999);
    }

    function testLimitesInvalidos() public {
        // Header > 127
        vm.expectRevert("JEC: Header excede 7 bits");
        JecEnterprise64BitPacker.pack(128, "Z", 0, 1, 1, 0, 0, 0, 0);

        // Ano > 99
        vm.expectRevert("JEC: Ano excede 7 bits (max 99)");
        JecEnterprise64BitPacker.pack(0, "Z", 100, 1, 1, 0, 0, 0, 0);

        // Mês 0
        vm.expectRevert("JEC: Mes invalido (1-12)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 0, 1, 0, 0, 0, 0);

        // Mês 13
        vm.expectRevert("JEC: Mes invalido (1-12)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 13, 1, 0, 0, 0, 0);

        // Dia 0
        vm.expectRevert("JEC: Dia invalido (1-31)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 0, 0, 0, 0, 0);

        // Dia 32
        vm.expectRevert("JEC: Dia invalido (1-31)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 32, 0, 0, 0, 0);

        // Hora 24
        vm.expectRevert("JEC: Hora invalida (0-23)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 24, 0, 0, 0);

        // Minuto 60
        vm.expectRevert("JEC: Minuto invalido (0-59)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 60, 0, 0);

        // Segundo 60
        vm.expectRevert("JEC: Segundo invalido (0-59)");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 0, 60, 0);

        // Microssegundo > 999999
        vm.expectRevert("JEC: Microssegundos excede limite");
        JecEnterprise64BitPacker.pack(0, "Z", 0, 1, 1, 0, 0, 0, 1000000);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // TESTES DO CONTRATO JecAuditoriaEVM
    // ═══════════════════════════════════════════════════════════════════════

    function testRegistarCheckpoint() public {
        uint64 codigo = 99;
        uint64 micro = 421983;

        // 2026-09-09 23:53:14 UTC = 1725832394 (timestamp Unix aproximado)
        vm.warp(1_725_832_394);

        uint64 jecTimestamp = auditoria.registarCheckpoint(codigo, micro);

        // Verificar se o checkpoint foi registrado
        assertTrue(auditoria.checkpointExiste(jecTimestamp));
        assertEq(auditoria.totalCheckpoints(), 1);

        // Extrair o header
        uint64 header = JecEnterprise64BitPacker.extractHeaderBits(jecTimestamp);
        assertEq(header, codigo);

        // Verificar a string visual (usando função view)
        string memory human = auditoria.timestampParaString(jecTimestamp, "TEST");
        // Para o timestamp 2026-09-09 23:53:14, o século deve ser 'Z' (2000-2099), ano 26, mês 9, dia 9, hora 23, min 53, seg 14
        // Dia 9 → 'J', Hora 23 → 'Y'
        assertEq(human, "TEST.Z26J9Y5314.421983");
    }

    function testCheckpointDuplicado() public {
        vm.warp(1_725_832_394);
        auditoria.registarCheckpoint(99, 421983);

        // Tentar registrar o mesmo timestamp novamente → deve reverter com JecCheckpointJaExiste
        vm.expectRevert(abi.encodeWithSignature("JecCheckpointJaExiste()"));
        auditoria.registarCheckpoint(99, 421983);
    }

    function testCheckpointComMicrosDiferentes() public {
        vm.warp(1_725_832_394);
        uint64 ts1 = auditoria.registarCheckpoint(99, 123456);
        uint64 ts2 = auditoria.registarCheckpoint(99, 123457);

        // Mesmo segundo, micros diferentes → timestamps diferentes
        assertTrue(ts1 != ts2);
        assertTrue(auditoria.checkpointExiste(ts1));
        assertTrue(auditoria.checkpointExiste(ts2));
        assertEq(auditoria.totalCheckpoints(), 2);
    }

    function testCustomErrors() public {
        // Header > 127
        vm.expectRevert(abi.encodeWithSignature("JecServidorExcede7Bits()"));
        auditoria.registarCheckpoint(128, 0);

        // Microssegundos > 999999
        vm.expectRevert(abi.encodeWithSignature("JecMicrossegundosExcede20Bits()"));
        auditoria.registarCheckpoint(0, 1000000);
    }

    function testConversaoTimestamp() public view {
        // 2026-09-09 23:53:14 UTC
        uint256 ts = 1_725_832_394;
        (string memory seculo, uint64 ano, uint64 mes, uint64 dia, uint64 hora, uint64 minuto, uint64 segundo) =
            auditoria.converterTimestampPublico(ts);

        assertEq(seculo, "Z");
        assertEq(ano, 26);
        assertEq(mes, 9);
        assertEq(dia, 9);
        assertEq(hora, 23);
        assertEq(minuto, 53);
        assertEq(segundo, 14);
    }

    function testTimestampParaStringDefault() public {
        uint64 packed = JecEnterprise64BitPacker.pack(
            99, "Z", 26, 9, 30, 23, 53, 14, 421983
        );
        string memory result = auditoria.timestampParaStringDefault(packed);
        assertEq(result, ".Z26J0Y5314.421983");
    }

    // Teste de integração: empacotar no contrato e desempacotar via biblioteca
    function testIntegracaoPackUnpack() public {
        vm.warp(1_725_832_394);
        uint64 codigo = 42;
        uint64 micro = 987654;
        uint64 jecTimestamp = auditoria.registarCheckpoint(codigo, micro);

        // Desempacotar manualmente para verificar os campos
        (uint64 h, uint64 sIdx, uint64 ano, uint64 mes, uint64 dia, uint64 hora, uint64 min, uint64 seg, uint64 mic) =
            JecEnterprise64BitPacker.unpack(jecTimestamp);

        assertEq(h, codigo);
        assertEq(sIdx, 0); // século Z
        assertEq(ano, 26);
        assertEq(mes, 9);
        assertEq(dia, 9);
        assertEq(hora, 23);
        assertEq(min, 53);
        assertEq(seg, 14);
        assertEq(mic, micro);
    }
}

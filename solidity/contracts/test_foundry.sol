// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/JecAuditoriaEVM.sol";

contract JecAuditoriaEVMTest is Test {
    JecAuditoriaEVM public auditoria;

    // Alfabeto JEC para referência nos testes
    string constant ALFABETO_JEC = "ABCDEFGHIJKLMNPQRSTUVWXYZ";

    function setUp() public {
        auditoria = new JecAuditoriaEVM();
    }

    /**
     * @dev Teste do ciclo de 2500 anos para anos dentro do range suportado pela EVM.
     *      IMPORTANTE: Testamos apenas anos >= 1970, pois block.timestamp nunca é negativo.
     */
    function testCiclo2500Anos() public view {
        // Apenas anos >= 1970 (range real da EVM)
        uint256[8] memory anos = [1970, 2000, 2026, 2400, 2500, 4900, 5000, 7470];
        uint64[8] memory indicesEsperados = [
            uint64(1970 / 100 % 25), // 19 → U
            uint64(2000 / 100 % 25), // 20 → V
            uint64(2026 / 100 % 25), // 20 → V
            uint64(2400 / 100 % 25), // 24 → Z
            uint64(2500 / 100 % 25), // 0  → A
            uint64(4900 / 100 % 25), // 24 → Z
            uint64(5000 / 100 % 25), // 0  → A
            uint64(7470 / 100 % 25)  // 24 → Z (7470/100 = 74, 74%25 = 24)
        ];

        // Letras esperadas (calculadas manualmente para clareza)
        string[8] memory letrasEsperadas = ["U", "V", "V", "Z", "A", "Z", "A", "Z"];

        for (uint256 i = 0; i < anos.length; i++) {
            uint256 timestamp = _dateToTimestamp(anos[i], 1, 1);

            (uint64 seculoIdx, uint64 ano2Digitos, , , , , ) =
                auditoria.converterTimestampPublico(timestamp);

            assertEq(
                seculoIdx,
                indicesEsperados[i],
                string(abi.encodePacked("Falha no indice do seculo para o ano ", vm.toString(anos[i])))
            );

            assertEq(
                ano2Digitos,
                uint64(anos[i] % 100),
                string(abi.encodePacked("Falha no ano de 2 digitos para ", vm.toString(anos[i])))
            );

            string memory letra = _idxToLetra(seculoIdx);
            assertEq(
                letra,
                letrasEsperadas[i],
                string(abi.encodePacked("Letra incorreta para o ano ", vm.toString(anos[i])))
            );
        }
    }

    /**
     * @dev Teste de fuzzing APENAS para anos >= 1970 (range real da EVM).
     *      Isso evita o problema de cast negativo no helper _dateToTimestamp.
     */
    function testCicloComDatasAleatorias(uint256 ano, uint256 mes, uint256 dia) public {
        // Restringir para o range real da EVM (block.timestamp nunca é negativo)
        ano = bound(ano, 1970, 10000);
        mes = bound(mes, 1, 12);
        dia = bound(dia, 1, 31);

        // Pular datas inválidas (ex: 31 de fevereiro)
        if (dia > _daysInMonth(ano, mes)) return;

        uint256 timestamp = _dateToTimestamp(ano, mes, dia);
        (uint64 seculoIdx, uint64 ano2Digitos, uint64 mesRet, uint64 diaRet, , , ) =
            auditoria.converterTimestampPublico(timestamp);

        // Verificar simetria da conversão
        assertEq(ano2Digitos, uint64(ano % 100), "Ano de 2 digitos incorreto");
        assertEq(mesRet, uint64(mes), "Mes incorreto");
        assertEq(diaRet, uint64(dia), "Dia incorreto");

        // Verificar ciclo de 2500 anos
        uint64 seculoEsperado = uint64((ano / 100) % 25);
        assertEq(seculoIdx, seculoEsperado, "Indice do seculo incorreto");
    }

    /**
     * @dev Teste específico para anos bissextos.
     */
    function testAnoBissexto() public view {
        // 29 de fevereiro de 2024 (ano bissexto)
        uint256 timestamp = _dateToTimestamp(2024, 2, 29);
        (, uint64 ano, uint64 mes, uint64 dia, , , ) =
            auditoria.converterTimestampPublico(timestamp);

        assertEq(ano, 24, "Ano incorreto");
        assertEq(mes, 2, "Mes incorreto");
        assertEq(dia, 29, "Dia incorreto");
    }

    /**
     * @dev Teste para verificar que o ciclo de 2500 anos funciona como esperado.
     */
    function testCicloCompleto() public view {
        // Ano 2000 → V (índice 20)
        uint256 ts2000 = _dateToTimestamp(2000, 1, 1);
        (uint64 seculo2000, , , , , , ) = auditoria.converterTimestampPublico(ts2000);
        assertEq(seculo2000, 20, "Ano 2000 deveria ser V (indice 20)");

        // Ano 4500 → V (índice 20) - mesmo ciclo, 2500 anos depois
        uint256 ts4500 = _dateToTimestamp(4500, 1, 1);
        (uint64 seculo4500, , , , , , ) = auditoria.converterTimestampPublico(ts4500);
        assertEq(seculo4500, 20, "Ano 4500 deveria ser V (indice 20) - ciclo de 2500 anos");

        // Ano 4500 tem o mesmo seculoIdx que 2000, mas ano2Digitos diferente
        (, uint64 ano2d2000, , , , , ) = auditoria.converterTimestampPublico(ts2000);
        (, uint64 ano2d4500, , , , , ) = auditoria.converterTimestampPublico(ts4500);
        assertEq(ano2d2000, 0, "Ano 2000 → 00");
        assertEq(ano2d4500, 0, "Ano 4500 → 00 (mesmo indice de seculo)");
    }

    function _idxToLetra(uint64 idx) internal view returns (string memory) {
        bytes memory alfabeto = bytes(ALFABETO_JEC);
        bytes memory resultado = new bytes(1);
        resultado[0] = alfabeto[uint256(idx)];
        return string(resultado);
    }

    /**
     * @dev Algoritmo exato O(1) de conversão Data -> Timestamp Unix (BokkyPooBah)
     *      Funciona APENAS para anos >= 1970 (range da EVM).
     */
    function _dateToTimestamp(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 timestamp)
    {
        // Esta função assume year >= 1970 (pré-condição dos testes)
        int256 _year = int256(year);
        int256 _month = int256(month);
        int256 _day = int256(day);

        int256 m = (_month - 14) / 12;
        int256 a = _year + 4800 + m;
        int256 julianDay = _day - 32075 +
            (1461 * a) / 4 +
            (367 * (_month - 2 - m * 12)) / 12 -
            (3 * ((a + 100) / 100)) / 4;

        // 2440588 = Dia Juliano correspondente a 01/01/1970
        // Para years >= 1970, este valor é sempre positivo
        int256 timestampSeconds = (julianDay - 2440588) * 86400;
        require(timestampSeconds >= 0, "_dateToTimestamp: year must be >= 1970");
        return uint256(timestampSeconds);
    }

    function _daysInMonth(uint256 year, uint256 month) internal pure returns (uint256) {
        if (month == 2) {
            return _isLeapYear(year) ? 29 : 28;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else {
            return 31;
        }
    }

    function _isLeapYear(uint256 year) internal pure returns (bool) {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    }
}

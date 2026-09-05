// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./JecEnterprise64BitPacker.sol";

contract JecAuditoriaEVM {
    using JecEnterprise64BitPacker for uint64;

    event EventoRegistado(uint64 indexed jecHeader, uint64 jecTimestamp);

    mapping(uint64 => string) public logsDoSistema;

    function registarCheckpoint(
        uint64 codigoServidor,
        uint64 seculoIdx,
        uint64 ano,
        uint64 mes,
        uint64 dia,
        uint64 hora,
        uint64 minuto,
        uint64 segundo,
        uint64 microssegundos
    ) external {
        uint64 jecTimestamp = JecEnterprise64BitPacker.pack(
            codigoServidor,
            seculoIdx,
            ano,
            mes,
            dia,
            hora,
            minuto,
            segundo,
            microssegundos
        );

        logsDoSistema[jecTimestamp] = "Hash: Checkpoint_NRS_Aprovado";
        uint64 headerExtraido = jecTimestamp.extractHeaderBits();

        emit EventoRegistado(headerExtraido, jecTimestamp);
    }
}

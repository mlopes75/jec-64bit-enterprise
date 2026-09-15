// test/JecEnterprise64Bit.t.sol
import "forge-std/Test.sol";
import "../src/JecEnterprise64BitPacker.sol";

contract JecEnterprise64BitTest is Test {
    using JecEnterprise64BitPacker for uint64;

    function testPackUnpackSymmetry() public {
        uint64 packed = JecEnterprise64BitPacker.packWithIdx(
            99,       // header
            0,        // século Z
            26,       // ano
            9,        // mês (Setembro)
            30,       // dia
            23,       // horaUTC
            53,       // minuto
            14,       // segundo
            421983    // micro
        );

        (uint64 h, uint64 s, uint64 a, uint64 m, uint64 d,
         uint64 hu, uint64 mi, uint64 se, uint64 mc) =
            JecEnterprise64BitPacker.unpack(packed);

        assertEq(h, 99);
        assertEq(s, 0);
        assertEq(a, 26);
        assertEq(m, 9);
        assertEq(d, 30);
        assertEq(hu, 23);
        assertEq(mi, 53);
        assertEq(se, 14);
        assertEq(mc, 421983);
    }

    function testHumanString() public {
        uint64 packed = JecEnterprise64BitPacker.packWithIdx(
            99, 0, 26, 9, 30, 23, 53, 14, 421983
        );
        string memory s = JecEnterprise64BitPacker.unpackToHumanString(packed, "LOG");
        assertEq(s, "LOG.Z26J0Y5314.421983");
    }

    function testCompareJec() public {
        uint64 a = 0;
        uint64 b = type(uint64).max;
        assertEq(JecEnterprise64BitPacker.compareJec(a, b), -1);
        assertEq(JecEnterprise64BitPacker.compareJec(b, a), 1);
        assertEq(JecEnterprise64BitPacker.compareJec(a, a), 0);
    }

    function testSpecVersion() public {
        assertEq(JecEnterprise64BitPacker.specVersion(), "1.0.0");
    }
}

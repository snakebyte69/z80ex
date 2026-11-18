#!/usr/bin/env perl

# Use .dat files to test z80ex_dasm
# needs z88dk-z80asm

use Modern::Perl;
use Path::Tiny;
use Config;
use Test::More;
use Test::Differences;

my $test = path($0)->basename(".pl");

# read .dat files
my %opcodes;
for (read_opcodes("opcodes_base.dat")) {
	my($code, $asm) = @$_;
	$opcodes{sprintf("%02x", $code)} = $asm;
	$opcodes{sprintf("%04x", 0xdd00 | $code)} = $asm;
	$opcodes{sprintf("%04x", 0xfd00 | $code)} = $asm;
}

for (read_opcodes("opcodes_cb.dat")) {
	my($code, $asm) = @$_;
	$opcodes{sprintf("%04x", 0xcb00 | $code)} = $asm;
}

for (read_opcodes("opcodes_ed.dat")) {
	my($code, $asm) = @$_;

	# opcodes_ed.dat has all shadow instructions on undocumented opcodes
	next if $asm =~ /NEG/ && $code != 0x44;
	next if $asm =~ /RETN/ && $code != 0x45;
	next if $asm =~ /IM 0/ && $code != 0x46;
	next if $asm =~ /RETI/ && $code != 0x4d;
	next if $asm =~ /IM 1/ && $code != 0x56;
	next if $asm =~ /IM 2/ && $code != 0x5e;
	next if $asm =~ /RRD/ && $code != 0x67;
	next if $asm =~ /RLD/ && $code != 0x6f;
	next if $asm =~ /LD \(\@\),HL/;
	next if $asm =~ /LD HL,\(\@\)/;

	$opcodes{sprintf("%04x", 0xed00 | $code)} = $asm;
}

for (read_opcodes("opcodes_ddfd.dat")) {
	my($code, $asm) = @$_;
	$opcodes{sprintf("%04x", 0xdd00 | $code)} = $asm;
	$opcodes{sprintf("%04x", 0xfd00 | $code)} = $asm;
}

for (read_opcodes("opcodes_ddfdcb.dat")) {
	my($code, $asm) = @$_;

	# opcodes_ddfdcb.dat has:
	# 	0x47="BIT 0,(REGISTER+$)"
	# shoulld be:
	# 	0x46="BIT 0,(REGISTER+$)"
	if ($code >= 0x40 && $code < 0x80) {
		$code--;
	}

	$opcodes{sprintf("%06x", 0xddcb00 | $code)} = $asm;
	$opcodes{sprintf("%06x", 0xfdcb00 | $code)} = $asm;
}

# make asm and bin data
my @asm;
for my $code (sort keys %opcodes) {
	my $asm = $opcodes{$code};
	my @bytes;
	for (my $i=0; $i < length($code); $i+=2) {
		push @bytes, hex(substr($code, $i, 2));
	}

	next if $asm =~ /shift|ignore|reset|NOP\*/;

	# $ - displacement for IX/IY+d
	if ( $asm =~ s/\$/0x23/ ) {
		splice @bytes, 2, 0, 0x23;
	}

	# # - byte
	if ( $asm =~ s/\#/0x12/ ) {
		push @bytes, 0x12;
	}

	# @ - word
	if ( $asm =~ s/\@/0x1234/ ) {
		push @bytes, 0x34, 0x12;
	}

	# % - jump offset
	if ( $asm =~ s/\%/ASMPC/ ) {
		push @bytes, -2 & 0xff;
	}

	# index register
	$asm =~ s/REGISTER/ $bytes[0] == 0xdd ? 'IX' : 'IY' /eg;

	# jump indirect
	$asm =~ s/JP (HL|IX|IY)/JP ($1)/;

	# IN F,(C)
	$asm =~ s/IN_F \(C\)/IN F,(C)/;

	push @asm, [$asm, \@bytes];
}

# build asm file
open my $fh, '>', "$test.asm" or die "Cannot open $test.asm: $!";
for (@asm) {
	my ($asm, $bytes) = @$_;
	say $fh " $asm";
}
close $fh;

# assemble
ok system("z88dk-z80asm -b -l $test.asm") == 0, "Assemble $test.asm";

# compare binary data
my @expected_bytes;
for (@asm) {
    my ( $asm, $bytes ) = @$_;
	push @expected_bytes, @$bytes;
}
my @got_bytes = map { ord } split //, path("$test.bin")->slurp_raw;

is_deeply \@got_bytes, \@expected_bytes, "Binary data matches expected bytes";

# build disassembler
ok system("gcc -I ../include -o dasm ../examples/dasm.c ../z80ex_dasm.c")==0, "Build disassembler";

# disassemble
ok system("./dasm $test.bin > $test.dis")==0, "Disassemble $test.bin";

# convert disassembly to match asm format
my @lines = path("$test.dis")->lines;
for (@lines) {
	s/^([0-9a-fA-F]{4})(: (JR|DJNZ).*)\#\1/$1$2ASMPC/;	# jump offsets
	s/^\s*[0-9A-Fa-f]{4}:\s*/ /;  	# remove address
	s/\s+t=.*//;       				# remove t-count
	s/\#/0x/g; 						# hex format
	s/JP (HL|IX|IY)/JP ($1)/;		# different format in disassembly
	s/LD_([AIR])_([AIR])/LD $1,$2/;	# different format in disassembly
        s/IN_F \(C\)/IN F,(C)/;    # different format in disassembly
}
path("$test.dis")->spew(@lines);

# compare disassembly with assembly
my $expected_dis = path("$test.asm")->slurp;
my $got_dis = path("$test.dis")->slurp;
eq_or_diff_text \$got_dis, \$expected_dis,
  "Disassembly matches expected assembly";


unlink "$test.asm", "$test.lis", "$test.o", "$test.bin", "$test.dis"
  if Test::More->builder->is_passing;
done_testing();


sub read_opcodes {
	my($file) = @_;

	my @lines = path($file)->lines;
	my @code;
	for (0..255) {
		$code[$_] = "NOP*";
	}	
	for (@lines) {
		if (/^0x([0-9a-f]{2})="([^"]+)"/i) {
			$code[hex($1)] = $2;
		}
	}
	@code = map {[$_, $code[$_]]} 0..$#code;
	return @code;
}

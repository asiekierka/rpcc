#!/usr/bin/perl

use constant {
	RAW_CODE	=> 1,
	PUSH		=> 2,
	POP			=> 3,
	STORE		=> 4,
	STORE_ABS	=> 5,
	LOAD		=> 6
};

my @emit = ();

sub optimize_emits {
	#Pass 1: Push/Pop
	for(my $i=1;$i<=$#emit;$i++)
	{
		my $em1 = $emit[$i-1];
		my $em2 = $emit[$i]; 
		if($em1->{type} == PUSH && $em2->{type} == POP && $em1->{register} == $em2->{register})
		{
			splice(@emit,$i-1,2);
			$i-=2;
		}
	}
	#Pass 2: Singular edits
	for(my $i=0;$i<=$#emit;$i++)
	{
		my $em = $emit[$i];
		if($em->{type} == STORE_ABS && $em->{value} == 0)
		{
			$emit[$i] = create_emit_raw("STZ ".$em->{address});
		}
	}
}
sub output_emits {
	foreach $em (@emit) {
		if($em->{type} == RAW_CODE) { print OUT $em->{data}; }
		elsif($em->{type} == LOAD) { print OUT "LD".$em->{register}." #".$em->{value}; }
		elsif($em->{type} == PUSH) { print OUT "PH".$em->{register}; }
		elsif($em->{type} == POP) { print OUT "PL".$em->{register}; }
		elsif($em->{type} == STORE_REG) { print OUT "ST".$em->{register}." ".$em->{address}; }
		elsif($em->{type} == STORE_ABS) { print OUT "LDA #".$em->{value}."\nSTA ".$em->{address}; }
		print OUT "\n";
	}
}
sub create_emit_raw {
	my ($opc) = @_;
	my $em = {};
	$em->{type} = RAW_CODE;
	$em->{data} = $opc;
	return $em;
}
sub emit_raw {
	my ($val) = @_;
	push(@emit,create_emit_raw($val));
}
sub create_emit_load {
	my ($val,$reg) = @_;
	my $em = {};
	$em->{type} = LOAD;
	$em->{value} = $val;
	$em->{register} = $reg;
	return $em;
}
sub emit_load {
	my ($val,$reg) = @_;
	push(@emit,create_emit_load($val,$reg));
}
sub create_emit_store {
	my ($val,$addr) = @_;
	my $em = {};
	$em->{type} = STORE_ABS;
	$em->{value} = $val;
	$em->{address} = $addr;
	return $em;
}
sub emit_store {
	my ($val,$addr) = @_;
	push(@emit,create_emit_store($val,$addr));
}
sub create_emit_push {
	my ($reg) = @_;
	my $em = {};
	$em->{type} = PUSH;
	$em->{register} = $reg;
	return $em;
}
sub emit_push {
	my ($reg) = @_;
	push(@emit,create_emit_push($reg));
}
sub create_emit_pop {
	my ($reg) = @_;
	my $em = {};
	$em->{type} = POP;
	$em->{register} = $reg;
	return $em;
}
sub emit_pop {
	my ($reg) = @_;
	push(@emit,create_emit_pop($reg));
}
sub create_emit_store_reg {
	my ($addr,$reg) = @_;
	my $em = {};
	$em->{type} = POP;
	$em->{address} = $addr;
	$em->{register} = $reg;
	return $em;
}
sub emit_store_reg {
	my ($addr,$reg) = @_;
	push(@emit,create_emit_store_reg($addr,$reg));
}

1;

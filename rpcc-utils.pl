#!/usr/bin/perl

sub is_operator {
	my $a = shift;
	if($a eq "+" || $a eq "-" || $a eq "*" || $a eq "/" || $a eq "%"
		|| $a eq "&" || $a eq "|" || $a eq "^" || $a eq "~")
			{ return 1; }
	else	{ return 0; }
}

1;

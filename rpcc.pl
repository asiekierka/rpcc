#!/usr/bin/perl
require "rpcc-emits.pl";
require "rpcc-utils.pl";

use constant {
	UNKNOWN		=> 0,
	NUMBER		=> 1,
	LPAREN		=> 2,
	RPAREN		=> 3,
	A_OPERATOR	=> 4,
	SEMICOLON	=> 5,
	VARNAME		=> 6,
	LABEL		=> 7,
	ERROR		=> 8,
	NAME		=> 9,
	L_OPERATOR	=> 10,
	SET_OPERATOR=> 11,
	C_OPERATOR	=> 12,
	COMMA		=> 13,
	FUNCTION	=> 14,
	EOF			=> 15,
	LNPAREN		=> 16,
	RNPAREN		=> 17,
	LSPAREN		=> 18,
	RSPAREN		=> 19
};

my $op_info = {
	"+="	=> {p => -2, a => "rl"},
	"-="	=> {p => -2, a => "rl"},
	"*="	=> {p => -2, a => "rl"},
	"/="	=> {p => -2, a => "rl"},
	"%="	=> {p => -2, a => "rl"},
	"&="	=> {p => -2, a => "rl"},
	"^="	=> {p => -2, a => "rl"},
	"|="	=> {p => -2, a => "rl"},
	">>="	=> {p => -2, a => "rl"},
	"<<="	=> {p => -2, a => "rl"},
	"="		=> {p => -2, a => "rl"},
	":"		=> {p => -1, a => "rl"},
	"?"		=> {p => -1, a => "rl"},
	"||"	=> {p => 1, a => "lr"},
	"&&"	=> {p => 2, a => "lr"},
	"|"		=> {p => 3, a => "lr"},
	"^"		=> {p => 4, a => "lr"},
	"&"		=> {p => 5, a => "lr"},
	"=="	=> {p => 6, a => "lr"},
	"!="	=> {p => 6, a => "lr"},
	"<"		=> {p => 7, a => "lr"},
	">"		=> {p => 7, a => "lr"},
	"<="	=> {p => 7, a => "lr"},
	">="	=> {p => 7, a => "lr"},
	"<<"	=> {p => 8, a => "lr"},
	">>"	=> {p => 8, a => "lr"},
	"+"		=> {p => 9, a => "lr"},
	"-"		=> {p => 9, a => "lr"},
	"*"		=> {p => 10, a => "lr"},
	"/"		=> {p => 10, a => "lr"},
	"%"		=> {p => 10, a => "lr"},
	"->"	=> {p => 13, a => "lr"}
};

my $unary_op_info = {
	"!"		=> {p => 11, a => "rl"},
	"~"		=> {p => 11, a => "rl"},
	"++"	=> {p => 11, a => "rl"},
	"--"	=> {p => 11, a => "rl"},
	"+"		=> {p => 11, a => "rl"},
	"-"		=> {p => 11, a => "rl"},
	"*"		=> {p => 11, a => "rl"},
	"&"		=> {p => 11, a => "rl"}
};

open(CODE, "<code.c");
open(OUT, ">code.s");
assemble_equation(parse_equation());
output_emits();
close(OUT);
open(OUT, ">codeo.s");
optimize_emits();
output_emits();
close(CODE);
close(OUT);


sub get_token {
	my $info = "";
	my $cget;
	my $type = UNKNOWN;
	while(1)
	{
		$cget = getc CODE;
		if ($cget =~ /\s/) { }
		elsif ($cget =~ /\d/)
		{
			$info .= $cget;
			$type = NUMBER;
			last;
		}
		elsif ($cget =~ /\w/ || ($cget eq "_"))
		{
			$info .= $cget;
			$type = NAME;
			last;
		}
		elsif ($cget eq "(")
		{
			$type = LPAREN;
			last;
		}
		elsif ($cget eq ")")
		{
			$type = RPAREN;
			last;
		}
		elsif ($cget eq "{")
		{
			$type = LNPAREN;
			last;
		}
		elsif ($cget eq "}")
		{
			$type = RNPAREN;
			last;
		}
		elsif ($cget eq "[")
		{
			$type = LSPAREN;
			last;
		}
		elsif ($cget eq "]")
		{
			$type = RSPAREN;
			last;
		}
		elsif ($cget eq ",")
		{
			$type = COMMA;
			last;
		}
		elsif ($cget eq ";")
		{
			$type = SEMICOLON;
			last;
		}
		elsif ($cget eq "=")
		{
			$info .= $cget;
			$type = SET_OPERATOR;
			last;
		}
		elsif ($cget eq "<" || $cget eq ">") # == (partially), <, >, <=, >= (partially)
		{
			$info .= $cget;
			$type = C_OPERATOR;
			last;
		}
		elsif ($cget eq "!") # !a, != (partially)
		{
			$info .= $cget;
			$type = L_OPERATOR;
			last;
		}
		elsif (is_operator($cget)) # +, -, *, /, %, &, |, ^, ~, && (partially), || (partially)
		{
			$info .= $cget;
			$type = A_OPERATOR;
			last;
		}
	}
	while(1)
	{
		$cget = getc CODE;
		if (($type==NUMBER && ($cget =~ /\d/)) || ($type==NAME && (($cget =~ /\w/) || ($cget =~ /\d/) || ($cget eq "_"))))
		{
			$info .= $cget;
		}
		elsif($type==NAME && ($cget eq ":")) # Labels
		{
			$type = LABEL;
			last;
		}
		elsif($type==NAME && ($cget eq "(")) # Functions
		{
			$type = FUNCTION;
			last;
		}
		elsif($type==A_OPERATOR && (($info eq "+" && $cget eq "+") || ($info eq "-" && $cget eq "-"))) # ++, --
		{
			$info .= $cget;
			last;
		}	
		elsif($type==C_OPERATOR && ($info eq "<" || $info eq ">") && $cget eq "=") # <=, =>
		{
			$info .= $cget;
			last;
		}
		elsif($type==C_OPERATOR && ($info eq "<" || $info eq ">") && $cget eq $info) # <<, >>
		{
			$type = A_OPERATOR;
			$info .= $cget;
		}
		elsif($type==SET_OPERATOR && $cget eq $info && $info eq "=") # ==
		{
			$type = C_OPERATOR;
			$info .= $cget;
			last;
		}
		elsif($type==A_OPERATOR && $cget eq "=") # +=, -=, etc
		{
			$type = SET_OPERATOR;
			$info .= $cget;
			last;
		}
		elsif($type==L_OPERATOR && $info eq "!" && $cget eq "=") # !=
		{
			$type = C_OPERATOR;
			$info .= $cget;
			last;
		}
		elsif($type==A_OPERATOR && ($info eq "&" || $info eq "|") && $cget eq $info) # &&, ||
		{
			$type = L_OPERATOR;
			$info .= $cget;
			last;
		}
		else { seek(CODE,-1,1); last; }
	}
	if($type==NAME) { $type=VARNAME; }
	print "Found token of type ".$type.", data '".$info."'\n";
	return make_token($type,$info);
}
sub make_token {
	my ($type, $data) = @_;
	my $token = {};
	$token->{type} = $type;
	$token->{data} = $data;
	return $token;
}

sub assemble_equation {
	my (@out_stack) = @_;
	foreach $token (@out_stack)
	{
		if($token->{type} == NUMBER)
		{
			emit_push($token->{data},"A");
		}
		elsif($token->{type} == A_OPERATOR)
		{
			my $addr = 0;
			emit_pop("A");
			emit_store_reg($addr,"A");
			if($token->{data} eq "+") { emit_raw("CLC"); emit_raw("ADC ".$addr); }
			elsif($token->{data} eq "-") { emit_raw("CLC"); emit_raw("SBC ".$addr); }
			elsif($token->{data} eq "*") { emit_raw("MUL ".$addr); }
			elsif($token->{data} eq "/") { emit_load(0,"A"); emit_raw("TAD"); emit_raw("DIV ".$addr); }
			elsif($token->{data} eq "%") { emit_load(0,"A"); emit_raw("TAD"); emit_raw("DIV ".$addr); emit_raw("TDA"); }
			elsif($token->{data} eq "^") { emit_raw("EOR ".$addr); }
			elsif($token->{data} eq "&") { emit_raw("AND ".$addr); }
			elsif($token->{data} eq "|") { emit_raw("ORA ".$addr); }
			elsif($token->{data} eq "<<") { emit_raw("CLC"); emit_raw("ASL ".$addr);  }
			elsif($token->{data} eq ">>") { emit_raw("CLC"); emit_raw("LSR ".$addr);  }
		}
	}
}
sub parse_equation {
	my @out_stack = ();
	my @op_stack = ();
	my $done = 0;
	my $errcode = 0;
	while($done==0)
	{
		my $is_unary = 0;
    	my $token = get_token();
		if($#op_stack<0 || $op_stack[$#op_stack]==LPAREN)
		{
			$is_unary = 1;
		}
		if($token->{type} == SEMICOLON)
		{
			$done=1;
			$errcode=0;
			while($#op_stack>=0)
			{
				$token = pop(@op_stack);
				if($token->{type} == LPAREN)
				{
					$errcode = -1;
					last;
				}
				else { push(@out_stack,$token); }
			}
		}
		elsif($token->{type} == NUMBER) { push(@out_stack,$token); }
		elsif($token->{type} == FUNCTION) { push(@op_stack,$token); push(@op_stack,make_token(LPAREN,"")); }
		elsif($token->{type} == LPAREN) { push(@op_stack,$token); }
		elsif($token->{type} == COMMA)
		{
			while($op_stack[$#op_stack]->{type} != LPAREN)
			{
				push(@out_stack,pop(@op_stack));
				if($#op_stack<0) { $done = 1; $errcode = -1; }
			}
		}
		elsif($token->{type} == RPAREN)
		{
			while($op_stack[$#op_stack]->{type} != LPAREN)
			{
				push(@out_stack,pop(@op_stack));
				if($#op_stack<0) { $done = 1; $errcode = -1; }
			}
			pop(@op_stack);
			if($#op_stack>=0 && $op_stack[$#op_stack]->{type} == FUNCTION)
			{
				push(@out_stack,pop(@op_stack));
			}
		}
		elsif($token->{type} == A_OPERATOR)
		{
			my $tok2 = $op_stack[$#op_stack];
			if($tok2->{type} == A_OPERATOR && (
				($op_info->{$token->{data}}->{a} eq "lr" && ($op_info->{$token->{data}}->{p} <= $op_info->{$tok2->{data}}->{p}))
				|| ($op_info->{$token->{data}}->{a} eq "rl" && ($op_info->{$token->{data}}->{p} < $op_info->{$tok2->{data}}->{p})) ) )
			{
				push(@out_stack,pop(@op_stack));
			}
			push(@op_stack,$token);
		}
	}
	foreach $out (@out_stack)
	{
		print "Found sorted token of type ".$out->{type}.", data '".$out->{data}."'\n";
	}
	return @out_stack;
}

#!/usr/bin/perl
# Net::Bind9::Update, Perl module wrapper for nsupdate
# 
# Copyright (c) 2011, Olof Johansson <olof@cpan.org> 
# All rights reserved.
# 
# This program is free software; you can redistribute it 
# and/or modify it under the same terms as Perl itself.  

=head1 NAME

Net::Bind9::Update, Perl module wrapper for nsupdate

=head1 SYNOPSIS

 my $update = Net::Bind9::Update->new(
         origin => 'example.com.',
	 ttl => 3600,
	 keyfile => '/etc/bind/session.key',
 );

=head1 DESCRIPTION

Update your dynamic zones directly from Perl. This module is a simple
wrapper around the nsupdate program, distributed as part of Bind9. You
start by adding some instructions to the module, and then run execute.

=cut

package Net::Bind9::Update;
use warnings;
use strict;
use Carp;

=head1 CONSTRUCTOR

Origin
ttl
class
keyfile
timeout
silent
server
port
local

=cut

sub new {
	my $class = shift;
	my $self = { 
		origin=>'.',
		ttl=>3600,
		class=>'IN',
		local=>0,
		timeout=>300,
		silent=>0,

		@_,

		instructions => [],
	};

	bless $self, $class;
}

=head1 METHODS

=head2 execute

Execute the instructions added using nsupdate. 

=cut

sub execute {
	my $self = shift;
	
	# weed out deleted instructions (see the undo method)
	my @instructions = grep {$_} @{$self->instructions};
	my $statusfile = '/tmp/nsupdate' or die $!; # FIXME, better tempfile

	open my $fh, '<', $statusfile;

	say $fh sprintf("server %s %s", 
		$server->{server}, $server->{port} // '' 
	) if $self->{server};
	
	say $fh sprintf("local %s %s", 
		$server->{server}, $server->{port} // '' 
	) if $self->{server};
	
	foreach(@instructions) {
		say $pipe $_;				
	}

	# Ceci n'est pas une pipe
	open my $pipe, _get_cmd($statusfile); 
	# TODO: Read the status file. Parse messages. Report to user.
	close $pipe;
	
	# clear the list of instructions
	$self->{instructions} = [];

	return 1;
}

=head2 add

Add a record to the zone. 

 $update->add(
	name=>$label, 
	type=>$rrtype, 
	ttl=>3600, 
	class=>'IN',
	data=>$data,
 );

ttl and class are optional.

=cut

sub add {
	my $self = shift;
	my $args = { @_ };

	my $domain = $args->{name};
	my $type = $args->{type};
	my $data = $args->{data};
	my $ttl = $args->{ttl} // $self->{ttl};
	my $class = $args->{class} // $self->{class};

	unless($domain) {
		$self->_carp "Domain was not supplied to add";
		return;
	}

	$domain = fqdnize($domain);
	push @{$self->{instructions}}, sprintf("update add %s %d %s %s %s",
		$domain, $ttl, $class, $type, $data
	);
}

=head2 del

Delete a domain, rrset or rr from the zone.

 $update->add(
	name=>$label, 
	type=>$rrtype, 
	ttl=>3600, 
	class=>'IN',
	data=>$data,
 );

ttl and class are optional.

=cut

sub del {
	my $self = shift;
	my $args = { @_ };

	my $domain = $args->{name};
	my $type = $args->{type};
	my $data = $args->{data};
	my $class = $args->{class} // $self->{class};

	unless($domain) {
		$self->_carp("Domain was not supplied to delete");
		return undef;
	}

	my $instruction = "update delete $domain ";

	if(defined $class) {
		$instruction .= "$class ";
	}

	if(defined $type) {
		$instruction .= "$type ";
		
		if(defined $data) {
			$instruction .= "$data";
		}
	}

	push @{$self->{instructions}}, $instruction;
}

=head2 list

Returns a list of the instructions that hasn't been sent to 
nsupdate yet. The index values of this array can be used as
argument to the undo method.

=cut

sub list {
	my $self = shift;

	return @{$self->{instructions};
}

=head2 undo

Before doing execute, you can delete an instruction. The 
argument is the array index, as seen when calling list.

=cut

sub undo {
	my $self = shift;
	my $n = shift;
	$self->{instructions}->[$n] = undef;
}

=head2 ttl

Sets or gets the default ttl set for new domains. Defaults to 3600.

=cut

sub ttl {
	my $self = shift;
	return $self->{ttl} unless @_;
	$self->{ttl} = shift;
}

=head2 class

Sets or gets the class used for new domains. 'IN' is the default.

=cut

sub origin {
	my $self = shift;
	return $self->{origin} unless @_;
	$self->{origin} = shift;
}

=head2 origin

Sets or gets the origin domain (the domain appended to labels witout
trailing .). Defaults to ".". This will be treated as a fully 
qualified domain, even if you don't have a trailing ".". If you omit
the "." you will get a warning, but the dot will be appended anyways.

 $update->origin('example.com.');
 my $origin = $update->origin;

=cut

sub origin {
	my $self = shift;
	return $self->{origin} unless @_;
	my $origin = shift;

	unless($origin =~ /\.$/) {
		$self->_carp("Unqualified domain given to origin; . appended");
		$origin .= '.';
	}

	$self->{origin} = shift;
}

=head1 INTERNAL METHODS

=head2 fqdnize

Helper method to make the domain fully qualified. This is done by 
appendning $self->origin to the domain unless it already ends with ".". 
This is primarily used internally by the module, but feel free to use 
it if you want to.

=cut

sub fqdnize {
	my $self = shift;
	my $label = shift;
	my $origin = $self->origin;
	return $label if $label =~ /\.$/;

	unless(defined $origin) {
		$self->_carp("Non fully qualified domain $domain");
		return undef;
	}

	return "$label." if $origin eq '.';
	return "$label.$origin"; 
}

sub _get_cmd {
	my $self = shift;
	my $tmpfile = shift;

	my $cmd = 'nsupdate ';

	$cmd .= "-t $self->{timeout}" if $self->{timeout};
	$cmd .= '-l '                 if $self->{local};
	$cmd .= "-k $self->{keyfile}" if $self->{keyfile};

	return $cmd;
}

sub _carp {
	my $self = shift;
	carp @_ unless $self->{silent};
}

1;

=head1 

=head1 TESTING

Parts of the test suite require a very specific environment setup. 
First: you will have to have a Bind9 running locally (or remotely, but 
that requires chaning in the F</t/test.ini> file). You will have to 
have a key for it, shared by Bind9 and your module. Last, but not 
least, you will have to make some dynamic zones: "example.com", 
"example.net" and "example.org". The zone files for these are 
available in F</t/data/db.example.{com,net,org}>. When all this is 
done:

 make test-bind9

=head1 AVAILABILITY

Latest stable version is availabe at CPAN:

 L<http://search.cpan.org/perldoc?Net::Bind9::Update>

Git repository (VCS) is available through Github:

 L<http://github.com/olof/Net-Bind9-Update>

=head1 COPYRIGHT

Copyright (c) 2011, Olof Johansson <olof@cpan.org>. All rights reserved.

This program is free software; you can redistribute it and/or modify it 
under the same terms as Perl itself.  


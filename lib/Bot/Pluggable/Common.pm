package Bot::Pluggable::Common;
$VERSION = 0.01;
use strict; 
use warnings;

=head1 NAME

Bot::Pluggable::Common - A Common Base Class for Bot::Pluggable Objects

=head1 SYNOPSIS

My::Plugin
use base qw(Bot::Pluggable::Common);

=head1 DESCRIPTION

I've written a few Bot::Pluggable modules now, and alot of stuff is 
common between all of them so I created a simple base class to put that stuff 
mostly because I think in OO terms first.

=cut


use POE;

sub new {
    my $class = shift;
    return bless {@_}, ref $class || $class;
}

sub init{
    my ($self, $bot) = @_;
    $self->{_BOT_} = $bot;
}

sub nick {
   my ($self, $nickstring) = @_;
		my ($nick, undef) = split(/!/, $nickstring, 2);
		return $nick;
}

sub tell {
    my ($self, $target, $message) = @_;
    $self->{_BOT_}->privmsg($target, $message) if $target and $message; 
}

sub do {
    my ($self, $target, $message) = @_;
    $self->{_BOT_}->ctcp($target, "ACTION ".$message) if $target and $message; 
}

sub names {
    my ($self, $channel) = @_;
    unless (time - ( $self->{_BOT_}{recent_names} || 0 ) < 10) {      # Unless we've asked for names recently....
        $self->{_BOT_}{recent_names} = time; 
        $self->{_BOT_}->names($channel)                               # reset the names list  
    }
}

sub Channels {
    my ($self, $target) = @_;
    my $heap = $poe_kernel->get_active_session()->get_heap();
    $heap->{Channels} = {} unless exists $heap->{Channels};
    $heap->{Channels} = $target if (defined $target);
    return $heap->{Channels};
}

#
# EVENTS
#

sub irc_001 {
    my ($self, $bot, $kernel) = @_[OBJECT, SENDER, KERNEL];
		 $self->init($bot);
		 return 0;
}

=head1 LIMITATIONS

It's just a base class what do you want?

=head1 COPYRIGHT

    Copyright 2003, Chris Prather, All Rights Reserved

=head1 LICENSE

You may use this module under the terms of the BSD, Artistic, oir GPL licenses,
any version.

=head1 AUTHOR

Chris Prather <chris@prather.org>

=cut

1;

# POE6/Tiny

####
# This module is a 'Tiny' Perl6 fork of POE using Ingo's POE-0.0.1 module
# Author credits: (Perl6) POE-0.0.1, Ingo Blechschmidt C<< <iblech@web.de> >>
#                 (Perl5) POE-0.0.1, Ingo Blechschmidt C<< <iblech@web.de> >>
# 
# The intent is to satisfy simple POE needs in Perl6, not to re-write POE
# Therefore this module does not have all of the bookkeeping embedded within POE,
# and that surely makes the POE code more stable.
# Note. The 1st iteration of this code is nearly an identical fork of POE-0.0.1
#
####
#module POE6::Tiny-0.0.2;

my $p6_version = '0.0.2';
my $poe6_debug = 0;

use POE6::Admin-Helper;
our $*App_die_on_status_error;
our $POE6::Session::Track = {};

class POE6::Kernel {
  # FIFO containers containing the events to call.
  has %!sync_events;
  has %!async_events;
  has %!wait_events;
  has @!async_supply;
  has $!async_supplier;
  has $!wait_supplier;
  has $!asyncsupply;
  has $!wait_supply;
  has $!async_channel;
  has $!wait_channel;
  has $!__DO_PULSE;
  has $!__PULSE_TIME = 3;
  # toggles to respond to bad coding
  has $.App_die_on_status_error = 0;

  submethod BUILD() {
    die "There can only be one instance of POE::Kernel."
      if defined $POE::Kernel;

    $POE::Kernel = self;
	$!async_supplier = Supplier.new;
	$!asyncsupply = $!async_supplier.Supply;
	$!async_channel = $!asyncsupply.Channel;
	$!wait_supplier = Supplier.new;
	$!wait_supply = $!wait_supplier.Supply;
	$!wait_channel = $!wait_supply.Channel;
	self!reactors();
  }

  method !__goto_die( :$file?, :$class!, :$method!, :$line!, :$why = '') {
	if $*App_die_on_status_error {
		die "Process requirements not met!\n\t$file class [" ~ $class ~ "] in method [" ~ $method ~ " ] at line $line\n\tRE: $why\n\tdying to fix\n";
	}
  }

  method add_session( $session ) {
	$session.link_kernel(self);
  }

  method make_session( :$classname ) {
	# namespace issues not resolved...
	# NOT USED
	#my $session = "$classname".new();
  }
  
  method !reactors() {
    start {
		react {
			whenever $!async_channel -> $key {
				self!async-react( key => $key );
			}
		}
	}
    start {
		react {
			whenever $!wait_channel -> $key {
				self!wait-react( key => $key );
			}
		}
	}
  }

  # Private method which pushes a given $callback to %!sync_events.
  # Uses the session's ctr value as a channel key for the session.
  # Uses a now() time key to sync callback to caller
  method !enqueue($session,$callback) {
	my $key = $session.SESSION_CTR;
    my $keynow = now;
	my $c = { $keynow => $callback };
    for %!sync_events.kv -> $_key, $content {
      if $_key ~~ /$key/ and $content ~~ Hash {
	    $content.push: ( $keynow => $callback );
		$c = $content;
	  }
	}
	%!sync_events.push: ( $key => $c );
	return $keynow;
  }

  # Private method which pushes a given $callback to @:async_events.
  method !async-queue($session,$dispatch,$event,@args) {
    my $key = now;
	my $h = {event => $event, session => $session, dispatch => $dispatch};
	$h.push: (args => @args);
    %!async_events.push: ( $key => $h );
    push @!async_supply, $key;
	return $key;
  }

  # Private method which pushes a given $callback to @:async_events.
  method !wait-queue($session,$dispatch,$event,@args) {
    my $key = now;
	my $h = {event => $event, session => $session, dispatch => $dispatch};
	$h.push: (args => @args);
    %!wait_events.push: ( $key => $h );
	return $key;
  }

  method !async-react( :$key! ) {
    for %!async_events.kv -> $_key, $content {
      if $_key ~~ /$key/ and $content ~~ Hash {
		my $session;
		my $dispatch;
		my $event = '';
		my @args;
		for keys $content -> $key {
			given $key {
				when /^session$/ {
					$session = $content.<session>;
				}
				when /^dispatch$/ {
					$dispatch = $content.<dispatch>;
				}
				when /^args$/ {
					@args = $content.<args>;
				}
				when /^event$/ {
					$event = $content.<event>;
				}
			}
		}
		if $event {
			my &code = {
				my $result := $session."$dispatch"($event, [,] @args);
				$result;
			}
			Promise.start( &code );
		}
		else {
			say "[async-react] REAL ERROR NO event [$event]";
		}
		
		## clear contents
		for $content.kv -> $_k, $c {
			$content{$_k}:delete;
		}

	  }
	}
	
	## remove keyed info from events hash - done.
	%!async_events{$key}:delete;
  }
  
  method !wait-react( :$key! ) {
    for %!wait_events.kv -> $_key, $content {
      if $_key ~~ /$key/ and $content ~~ Hash {
		my $session;
		my $dispatch;
		my $event = '';
		my @args;
		for keys $content -> $key {
			given $key {
				when /^session$/ {
					$session = $content.<session>;
				}
				when /^dispatch$/ {
					$dispatch = $content.<dispatch>;
				}
				when /^args$/ {
					@args = $content.<args>;
				}
				when /^event$/ {
					$event = $content.<event>;
				}
			}
		}
		if $event {
			my &code = {
				my $result := $session."$dispatch"($event, [,] @args);
				$result;
			}
			Promise.start( &code );
		}
		else {
			say "[wait-react] REAL ERROR NO event [$event]";
		}
		
		## clear contents
		for $content.kv -> $_k, $c {
			$content{$_k}:delete;
		}

	  }
	}
	
	## remove keyed info from events hash - done.
	%!wait_events{$key}:delete;
  }

 
  ## base pulse method
  multi method __tstep() {
	self!pulse();
  }
  ## Perform one step -- i.e. get an event from @:events and call it.
  multi method __tstep( $session!, Str $type!, $key! ) {
	given $type {
		when "sync" {
			my $skey = $session.SESSION_CTR;
			for %!sync_events.kv -> $_key, $chann {
				if $_key ~~ $skey and $chann ~~ Hash {
					for $chann.kv -> $now_key, $content {
						if $now_key ~~ $key {
							my &callback = $content;
							$chann{$_key}:delete;
							return &callback();
						}
					}
				}
			}
			return;
		}
	}
  }

  method !pulse() {
	if $!__DO_PULSE {
		$!__DO_PULSE = 0;
		sleep $!__PULSE_TIME;
		if $poe6_debug {
			say "do pulse t[$!__PULSE_TIME] state[$!__DO_PULSE]";
		}
		self!energize_pulse();
	}
	return;
  }
  
  method !energize_pulse() {
	#say "energizing pulse";
	$!__DO_PULSE = 1;
	self.__tstep();
  }

  method run() {
  }

  method run_loop() {
	self!energize_pulse();
  }

  # Post $event to $session and [implicitly] return the result.
  # The session's event handler won't be executed until the
  # callback has been enqueue[d](). Note that is a 'keyed' process,
  # where the action-key has a now() time to ensure that the proper
  # callback is retrieved - and the implicit return is sync'ed
  method post($session, Str $event, *@args) {
    # Push our callback on @!events.
	# POE::Session check - no direct type checking
	if !$session.IS_SESSION {
						self!__goto_die( 
							file => $?FILE, 
							class => ::?CLASS.^name, 
							method => &?ROUTINE.name, 
							line => $?LINE, 
							why => "Bad SESSION object[ ~ $session.^name ~ ] at ctr[ ~ $session.SESSION_CTR ~ ]" 
							);
	}
	if $poe6_debug {
		say "POST: session class name: " ~ $session.^name ~ " count:[" ~ $session.SESSION_CTR ~"][" ~ $session.WHICH ~"]";
	}
    my $action_key = self!enqueue( $session, {
      my $result := $session.dispatch($event, [,] @args);
      $result;
    });

    # Enter the _tstep loop - return to this point.
	self.__tstep( $session, 'sync', $action_key );
  }

  # Wrapper to Delay an $event to $session.
  method delay($session, Str $event, Int $timeout = 1, *@args) {
    # Send async delay-event "delay-sig" method
	# This allows for dispatch management - and optional return signals.
	#	my $dispatch = $!DISPATCH_SIG;
	self!delay-sig( session => $session, event => $event, timeout => $timeout, args => @args );
  }

  # Delay an $event to a $session and return a boolean true signal.
  method !delay-sig( :$session!, Str :$event!, Int :$timeout = 1, :$dispatch = 'dispatch_sig', :@args) {
    # Push our delayed and async callback on @!wait_events.
	if $poe6_debug {
		say "DELAY: session class name: " ~ $session.WHO ~ " count:[" ~ $session.SESSION_CTR ~"][" ~ $session.WHICH ~"]";
	}
    my $action_key = self!wait-queue($session,$dispatch,$event,@args);

	Promise.in($timeout).then: {
		say "Trigger waited event";
		$!wait_supplier.emit($action_key);
	}

	if $poe6_debug {
		return say "DELAY: returned from delay-sig";
	}
	return True;
  }

  # Wrapper to Yield an $event in a $session.
  method yield($session, Str $event, *@args) {
    # Send async yeild-event "yield-sig" method
	# This allows for dispatch management - and optional return signals.
	#	my $dispatch = $!DISPATCH_ASYNC;
	self!yield-sig( session => $session, event => $event, args => @args );
  }
  
  # Yield an $event in a $session and return a boolean true signal.
  method !yield-sig( :$session!, Str :$event!, :$dispatch = 'dispatch_sig', :@args) {
    # Push our async callback on @!async_events.
	if $poe6_debug {
		say "YIELD: session class name: " ~ $session.WHO ~ " count:[" ~ $session.SESSION_CTR ~"][" ~ $session.WHICH ~"]";
	}
    my $action_key = self!async-queue($session,$dispatch,$event,@args);

	$!async_supplier.emit($action_key);

	if $poe6_debug {
		return say "YIELD: returned from yield-sig";
	}
	return True;
  }

}

####
# POE6 now uses a Session role to bring in common methods
####
class POE::Session is export {
  has $!SESSION_ID;
  has $.IS_SESSION;
  has $!SESSION_NAME;
  has $!SESSION_ALIAS;
  has Int $.SESSION_CTR;
  has $!POE6-KERNEL;
  has %!SESS_OBJECT_STATES;
  
  submethod BUILD(:$poe_kernel?,:$session_alias?,:%object_states?) {
	$!IS_SESSION = 1;
	$!SESSION_NAME = self.WHICH;
	if self.WHICH !~~ /\|(\d+)/ {
		die "Bad id match in new session:[" ~ self.WHICH ~"]";
	}
	$!SESSION_ID = $0;
	my $ctr = $POE6::Session::Track.elems;
	$ctr++;
    $!SESSION_CTR = $ctr;
	$POE6::Session::Track.push: ( $!SESSION_ID => $!SESSION_CTR );
	if $session_alias { $!SESSION_ALIAS = $session_alias; }
	
	# if sent, add POE::Kernel to session state
	if $poe_kernel {
		$!POE6-KERNEL = $poe_kernel;
	}

  }
  
  method session_id(Int :$session_id?) {
	if $session_id { $!SESSION_ID = $session_id; }
	return $!SESSION_ID;
  }
  method session_alias(Int :$session_alias?) {
	if $session_alias { $!SESSION_ALIAS = $session_alias; }
	if !$!SESSION_ALIAS { return $!SESSION_NAME; }
	return $!SESSION_ALIAS;
  }

  method link_kernel( $kernel! ) {
	$!POE6-KERNEL = $kernel;
  }
  
  method dispatch(Str $event, *@args) {
    die 'Please override &dispatch in your subclass of POE6::Session.';
  }

}

#
#Note. The global variable $POE::Kernal should be created outside of the class package
#  to ensure the namespace is populated. Otherwise a 'Cannot find symbol' error may occur.
  
##--Notepad++

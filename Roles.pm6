# POE6/Roles

####
# Roles module
# $p6_version = '0.0.3';
#
# Within-
# module POE6::Tiny;
####

my $p6_version = '0.0.3';

use POE6::Admin-Helper;

role Kernel::Main {
  # FIFO containers containing the events to call.
  has %!sync_events;
  has %!async_events;
  has %!wait_events;
  has $!async_supplier;
  has $!wait_supplier;
  has $!asyncsupply;
  has $!wait_supply;
  has $!async_channel;
  has $!wait_channel;
  has $!__DO_PULSE;
  has $!__PULSE_TIME = 3;
  has %!SESSIONS_INFO;
  has %!SESSION_Alias_Lookup;
  has %!DCHANNEL_DESTINATIONS;
  has %!DCHANNEL_CHANNEL_CTR;
  has %!DCHANNEL_INSTRUCTIONS;
  has %!DCHANNEL_BACKCALLS;
  has $!DCHANNEL_ID_CTR = 0;
  # toggles to respond to bad coding
  has $.App_die_on_status_error = 0;
  has $!pctr = 0;

  submethod BUILD() {
    die "There can only be one instance of POE::Kernel."
      if defined $POE::Kernel;

    $POE::Kernel = self;
	
	self!make_channels();
	
	self!Build_Start();
  }

  ## starter method to override for adding custom BUILD actions
  method !Build_Start() {
  }
  
  method !__goto_die( :$file?, :$class!, :$method!, :$line!, :$why = '') {
	if $*App_die_on_status_error {
		die "Process requirements not met!\n\t$file class [" ~ $class ~ "] in method [" ~ $method ~ " ] at line $line\n\tRE: $why\n\tdying to fix\n";
	}
  }

  method add_session( $session ) {
	$session.link_kernel(self);
	my $key = $session.session_id();
	my $alias = $session.session_alias();
	my %h = ( object => $session, ctr => $session.SESSION_CTR, alias => $alias );
	%!SESSIONS_INFO.push: ( $key => %h );
	%!SESSION_Alias_Lookup.push: ( $alias => $key );
  }
  method session_object_by_id( $session_from_id ) {
	for %!SESSIONS_INFO.kv -> $key, %h {
		if $key ~~ /^$session_from_id$/ {
			for keys %h -> $_key {
				given $_key {
					when "object" {
						return %h<object>;
					}
				}
			}
		}
	}
	return Nil;
  }
  method lookup_session_id( $alias! ) {
	if defined %!SESSION_Alias_Lookup{$alias} {
		return %!SESSION_Alias_Lookup{$alias};
	}
	for %!SESSION_Alias_Lookup.kv -> $key, $val {
		if $key ~~ /$alias/ {
			return $val;
		}
	}
	if !defined %!SESSIONS_INFO{$alias} {
			if $*poe6_debug {
				## dump alias lookup hash to screen
				for %!SESSION_Alias_Lookup.kv -> $key, $val {
					say "\n[alias-lookup] key[$key] val[$val]";
				}
			}
			self!__goto_die( 
				file => $?FILE, 
				class => ::?CLASS.^name, 
				method => &?ROUTINE.name, 
				line => $?LINE, 
				why => "Bad SESSION ID[ ~ $alias ~ ] alias is not registed [$alias]", 
				);
	}
	return $alias;
  }
  

  ## make supplier channels for the async and wait reactors.
  ## : the async reactor handles async calls from yield methods.
  ## : the wait reactor handles async calls from delay methods on a promise timeout.
  method !make_channels() {
	$!async_supplier = Supplier.new;
	$!asyncsupply = $!async_supplier.Supply;
	$!async_channel = $!asyncsupply.Channel;
	$!wait_supplier = Supplier.new;
	$!wait_supply = $!wait_supplier.Supply;
	$!wait_channel = $!wait_supply.Channel;
	self!reactors();
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

  ## dedicated session-to-session messaging process
  ## '$session_from_key' and '$session_to_key' are the sender and receiver aliases or session_ids, respectively.
  ## '$destination' is the dispatch option within the called (to) session for the message call.
  ## '$backcall_dispatch' is an optional dispatch method within the caller (from) session to accept a message response 
  ## '$backcall_option' is an optional dispatch option within the caller (from) session to accept a message response 
  ## '$await_response' is a falsy toggle to indicate that the called session will send a response back to the caller
  ## '$timeout' is the timeout for how long the message channel will wait before timing out and sending a closing response (0 = indefinite)
  ## '$responder' is an optional method call to use an alternate backcall method for this channel
  ## RETURNS 'dchannel_id' for use in accessing the dedicated channel. An integer value starting at 1.
  multi method register_dchannel( :$session_from_key!, :$session_to_key!, :$destination!, :$backcall_dispatch = 'dispatch_backcall', :$backcall_option = 'backcall', :$await_response = 0, :$timeout = 0, :$responder? ) {
	my $session_from_id = self.lookup_session_id( $session_from_key );
	my $session_to_id = self.lookup_session_id( $session_to_key );
	my $dest_key = $session_from_id ~ ":" ~ $session_to_id ~ ":" ~ $destination ~ ":" ~ $await_response;
	for %!DCHANNEL_INSTRUCTIONS.kv -> $_key, $content {
		if $_key ~~ /^$dest_key$/ and $content ~~ Hash {
			say "Dedicated Channel already exists!";
			return Nil;
		}
	}
	$!DCHANNEL_ID_CTR++;
	my $dchannel_id = $!DCHANNEL_ID_CTR;
	my $c = { 
		dchannel_id => $dchannel_id, 
		session_from_id => $session_from_id, 
		session_to_id => $session_to_id, 
		destination => $destination, 
	}
	if $backcall_dispatch and $await_response {
		$c.push: ( backcall_dispatch => $backcall_dispatch );
		$c.push: ( await_response => $await_response );
		$c.push: ( timeout => $timeout );
		if $responder { $c.push: ( responder => $responder ); }
		my $sess = self.session_object_by_id( $session_from_id ); ## NOTE that the backcall goes back to the caller (from session)
		%!DCHANNEL_BACKCALLS.push: ( $dchannel_id => { session => $sess, backcall_option => $backcall_option, backcall_dispatch => $backcall_dispatch } );
	}
	%!DCHANNEL_INSTRUCTIONS.push: ( $dest_key => $c );

	## fetch session_to object and load it into DCHANNEL_DESTINATIONS
	## Note: $info_key = $session.session_id();
	for %!SESSIONS_INFO.kv -> $_key, $content {
		if $_key ~~ /^$session_to_id$/ and $content ~~ Hash {
			my $ch = { $dchannel_id => $dest_key };
			my $session;
			for keys $content -> $_ckey {
				given $_ckey {
					when /^object$/ {
						$session = $content.<object>;
					}
					when /^dchannels$/ {
						my $chann = $content.<dchannels>;
						if $chann ~~ Hash {
							## merge $chann into $ch
							$chann.push: ( $dchannel_id => $dest_key );
							$ch = $chann;
						}
					}
				}
			}
			$content.<dchannels> = $ch;
			if defined $session {
				%!DCHANNEL_DESTINATIONS.push: ( $dchannel_id => $session );
				$session.dchannel_config( dchannel_key => $dest_key, config_info => $c );
				return $dchannel_id;
			}
		}
	}
	if $*poe6_debug {
			self!__goto_die( 
				file => $?FILE, 
				class => ::?CLASS.^name, 
				method => &?ROUTINE.name, 
				line => $?LINE, 
				why => "Bad DCHANNEL setup, session_from[ ~ $session_from_id ~ ] session_to[$session_to_id]", 
				);
	}
	return Nil;
  }

  ## dedicated session-to-session messaging process
  ##   method uses a dedicated channel id (dchannel_id) to access 
  ##   a pre-registered configuration for sending the message
  multi method dchannel_message( :$dchannel_id!, :$message! ) {
	for %!DCHANNEL_DESTINATIONS.kv -> $_key, $session {
		if $_key ~~ /^$dchannel_id$/ {
			if !defined %!DCHANNEL_CHANNEL_CTR{$dchannel_id} {
				%!DCHANNEL_CHANNEL_CTR{$dchannel_id} = 0;
			}
			%!DCHANNEL_CHANNEL_CTR{$dchannel_id}++;
			my $decrement = $session.rcpt_dchannel_message( dchannel_id => $dchannel_id, message => $message );
			if $decrement {
				%!DCHANNEL_CHANNEL_CTR{$dchannel_id}--;
			}
			return;
		}
	}
	if $*poe6_debug {
		say "[dmess@krnl] WARNING! Failed to find a registered channel for ID[$dchannel_id]";
	}
	return;
  }
  ## dedicated session-to-session messaging process with a test option
  ## the test option sends the message to pre-defined test dispatch options
  multi method dchannel_message( $dchannel_id!, $test!, $message?  ) {
	if $test {
		for %!DCHANNEL_DESTINATIONS.kv -> $_key, $session {
			if $_key ~~ /^$dchannel_id$/ {
				my %mess = ( i_mess => 0, mess => "NOP" );
				say "[dmess@krnl] TESTING ch_id["~$dchannel_id~"] session["~$session.gist~"]";
				$session.rcpt_dchannel_message( dchannel_id => $dchannel_id, test_message => item(%mess), test => 1 );
			}
		}
		return;
	} 
	say "[dmess@krnl] WARNING! Failed to find a registered channel for ID[$dchannel_id]";
	return;
  }

  ## take the message response sent on the dchannel and route the message
  ## to the original session with the registered backcall options
  method backcall_dchannel(:$dchannel_id!, :$message!) {
	## lookup backcall_dispatch info using dchannel id
	for %!DCHANNEL_BACKCALLS.kv -> $_key, $content {
		if $_key ~~ /^$dchannel_id$/ and $content ~~ Hash {
			my ($session, $backcall_option, $dispatch);
			for keys $content -> $_ckey {
				given $_ckey {
					when /^session$/ {
						$session = $content.<session>;
					}
					when /^backcall_option$/ {
						$backcall_option = $content.<backcall_option>;
					}
					when /^backcall_dispatch$/ {
						$dispatch = $content.<backcall_dispatch>;
					}
				}
			}
			## send message
			start { $session."$dispatch"(destination => $backcall_option, message => $message); }
			if defined %!DCHANNEL_CHANNEL_CTR{$dchannel_id} and %!DCHANNEL_CHANNEL_CTR{$dchannel_id} > 0 {
				%!DCHANNEL_CHANNEL_CTR{$dchannel_id}--;
			}
			return;
		}
	}
	return Nil;
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
		if $*poe6_debug {
			$!pctr++;
			say "do pulse, time[$!__PULSE_TIME] ctr[$!pctr]";
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
	if $*poe6_debug {
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
	if $*poe6_debug {
		say "DELAY: session class name: " ~ $session.WHO ~ " count:[" ~ $session.SESSION_CTR ~"][" ~ $session.WHICH ~"]";
	}
    my $action_key = self!wait-queue($session,$dispatch,$event,@args);

	Promise.in($timeout).then: {
		say "Trigger waited event";
		$!wait_supplier.emit($action_key);
	}

	if $*poe6_debug {
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
	if $*poe6_debug {
		say "YIELD: session class name: " ~ $session.WHO ~ " count:[" ~ $session.SESSION_CTR ~"][" ~ $session.WHICH ~"]";
	}
    my $action_key = self!async-queue($session,$dispatch,$event,@args);

	$!async_supplier.emit($action_key);

	if $*poe6_debug {
		return say "YIELD: returned from yield-sig";
	}
	return True;
  }

  ## END of Kernel::Main role
}

role POE6::Session {
  has $!SESSION_ID;
  has $.IS_SESSION;
  has $!SESSION_NAME;
  has $!SESSION_ALIAS;
  has Int $.SESSION_CTR;
  has $!POE6-KERNEL;
  has %!SESS_OBJECT_STATES;
  has POE6::Admin-Helper $!admin_helper handles POE6::Admin-Helper.new();
  
  ## set reactor message channels
  has %!sync_mess;
  has %!async_mess;
  has $!sync_supplier;
  has $!sync_supply;
  has $!sync_channel;
  has $!async_supplier;
  has $!async_supply;
  has $!async_channel;
  has $!reactors_started = 0;
  has %!std_message = (
				i_mess => Nil,
				mess => '',
				a_mess => item(),
				h_mess => item{},
				);
  has %!DCHANNEL_DISPATCH_TABLE;
  has %!DCHANNEL_PROMISES;
  has %!DCHANNEL_TOKENS;
  has %!DCHANNEL_TOKEN_MAPPER;
  has $!DCHANNEL_DISPATCH = 'dispatch_dchannel';
  has $!DCHANNEL_RESPONDER = 'send_back_on_dchannel';

  submethod BUILD(:$poe_kernel?,:$alias?,:%object_states?,:$set_session_messaging = 0) {
	$!IS_SESSION = 1;
	$!SESSION_NAME = self.WHICH;
	if self.WHICH !~~ /\|(\d+)/ {
		my $method = &?ROUTINE.name;
		$!admin_helper.__goto_die( 
			file => $?FILE, 
			class => ::?CLASS.^name, 
			method => &?ROUTINE.name, 
			line => $?LINE, 
			why => "Bad ID match["~self.WHICH~"] for[$!SESSION_ID]", 
			App_die_on_status_error => $*App_die_on_status_error,
		);
	}
	$!SESSION_ID = $0;
	$!SESSION_ALIAS = $!SESSION_ID;
	$!SESSION_CTR = $POE6::Session::Track.elems;
	$!SESSION_CTR++;
	if $alias { $!SESSION_ALIAS = $alias; }
	$POE6::Session::Track.push: ( $!SESSION_CTR => $!SESSION_ID );
	$POE6::Session::Alias-Lookup.push: ( $!SESSION_ALIAS => $!SESSION_ID );
	
	# if sent, add POE::Kernel to session state
	if $poe_kernel {
		$!POE6-KERNEL = $poe_kernel;
		## auto-add session into kernel environment
		$!POE6-KERNEL.add_session( self );
	}

	if $set_session_messaging {
		self!make_messaging_channels();
	}

	%!SESS_OBJECT_STATES.push: ( '_start' => '_poe_start' );
	%!SESS_OBJECT_STATES.push: ( '_stop' => '_poe_stop' );
  }
  
  ## session_id lookup. Will only get, not reset initial id value
  method session_id() {
	return $!SESSION_ID;
  }
  
  method session_alias(:$alias?) {
	if $alias { $!SESSION_ALIAS = $alias; }
	if !$!SESSION_ALIAS { return $!SESSION_ID; }
	return $!SESSION_ALIAS;
  }
  
  method set_session_messaging($toggle = 0) {
	if !$toggle {
		say "Nothing done. Session ("~$!SESSION_ALIAS~") messaging request is Null/Nil/Falsy.";
		return;
	}
	if $!reactors_started {
		say "Nothing done. Session ("~$!SESSION_ALIAS~") messaging state already enabled.";
		return;
	}
	self!make_messaging_channels();
	return;
  }

  ## make supplier channels for the sync and async reactors.
  ## : the async reactor handles async calls from yield methods.
  ## : the sync reactor handles sync (await) calls that require a response, these calls have a timeout.
  method !make_messaging_channels() {
	$!async_supplier = Supplier.new;
	$!async_supply = $!async_supplier.Supply;
	$!async_channel = $!async_supply.Channel;
	$!sync_supplier = Supplier.new;
	$!sync_supply = $!sync_supplier.Supply;
	$!sync_channel = $!sync_supply.Channel;
	self!reactors();
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
			whenever $!sync_channel -> $key {
				self!sync-react( key => $key );
			}
		}
	}
	$!reactors_started = 1;
	if $*poe6_debug {
		say "Session ("~$!SESSION_ALIAS~") messaging configured <enabled>.";
	}
  }

  method dchannel_config( :$dchannel_key!, :$config_info! ) {
	if $config_info !~~ Hash {
		if $*poe6_debug {
			$!admin_helper.__goto_die( 
				file => $?FILE, 
				class => ::?CLASS.^name, 
				method => &?ROUTINE.name, 
				line => $?LINE, 
				why => "DCHANNEL config info is corrupted["~$config_info~"] for[$dchannel_key]", 
				App_die_on_status_error => $*App_die_on_status_error,
			);
		}
		return Nil;
	}
	my ($dchannel_id,$destination,$session_from_id,$dispatch,$responder);
	my $await = 0;
	my $timeout = 0;
	for keys $config_info -> $_key {
		given $_key {
 			when /^dchannel_id$/ {
				$dchannel_id = $config_info.<dchannel_id>;
			}
 			when /^destination$/ {
				$destination = $config_info.<destination>;
			}
 			when /^dispatch$/ {
				$dispatch = $config_info.<dispatch>;
			}
 			when /^responder$/ {
				$responder = $config_info.<responder>;
			}
 			when /^await_response$/ {
				$await = $config_info.<await_response>;
			}
 			when /^timeout$/ {
				$timeout = $config_info.<timeout>;
			}
 			when /^session_from_id$/ {
				$session_from_id = $config_info.<session_from_id>;
			}
		}
	}
	if $dchannel_id {
		%!DCHANNEL_DISPATCH_TABLE.push: ( $dchannel_id => $destination );
		my $sess = $!POE6-KERNEL.session_object_by_id( $session_from_id );
		my $h = { to_session => $sess };
		if $await {
			$h.push: ( timeout => $timeout );
		}
		if $dispatch {
			$h.push: ( dispatch_override => $dispatch );
		}
		if $responder {
			$h.push: ( responder_override => $responder );
		}
		%!DCHANNEL_PROMISES.push: ( $dchannel_id => $h );
	}
	
	return;
  }

  multi method rcpt_dchannel_message( :$dchannel_id!, :$message! ) {
	my $destination;
	for %!DCHANNEL_DISPATCH_TABLE.kv -> $key, $dest {
		if $key ~~ /^$dchannel_id$/ {
			$destination = $dest;
		}
	}
	if $destination {
		my $timeout = 0;
		my $dispatch = $!DCHANNEL_DISPATCH;
		my $responder;
		for %!DCHANNEL_PROMISES.kv -> $_key, $content {
			if $_key ~~ /^$dchannel_id$/ and $content ~~ Hash {
				for keys $content -> $_ckey {
					given $_ckey {
						when /^timeout$/ {
							$timeout = $content.<timeout>;
						}
						when /^dispatch_override$/ {
							$dispatch = $content.<dispatch_override>;
						}
						when /^responder_override$/ {
							$responder = $content.<responder_override>;
						}
					}
				}
			}
		}
		my $emit_key;
		if $timeout {
			if $responder {
				$emit_key = self._mess-enqueue($timeout,$dchannel_id,$dispatch,$destination,$message,$responder);
			} else {
				$emit_key = self._mess-enqueue($timeout,$dchannel_id,$dispatch,$destination,$message);
			}
			
			## NOTE: the timeout promise is set with the dispatch option/action
			## trigger reactor
			$!sync_supplier.emit($emit_key);
			return 0;
		} else {
			if $responder {
				$emit_key = self._mess-enqueue($dispatch,$destination,$message,$responder);
			} else {
				$emit_key = self._mess-enqueue($dispatch,$destination,$message);
			}
			## trigger reactor
			$!async_supplier.emit($emit_key);
			return 1;
		}
	}
	if $*poe6_debug {
		$!admin_helper.__goto_die( 
			file => $?FILE, 
			class => ::?CLASS.^name, 
			method => &?ROUTINE.name, 
			line => $?LINE, 
			why => "DCHANNEL config destination is corrupted for dchannel[$dchannel_id]", 
			App_die_on_status_error => $*App_die_on_status_error,
		);
	}
	return Nil;
  }
  multi method rcpt_dchannel_message( :$dchannel_id!, :$test_message!, :$test! ) {
	my $destination;
	for %!DCHANNEL_DISPATCH_TABLE.kv -> $key, $dest {
		if $key ~~ /^$dchannel_id$/ {
			$destination = $dest;
		}
	}
	if $destination {
		my $timeout = 0;
		my $dispatch = $!DCHANNEL_DISPATCH;
		for %!DCHANNEL_PROMISES.kv -> $_key, $content {
			if $_key ~~ /^$dchannel_id$/ and $content ~~ Hash {
				for keys $content -> $_ckey {
					given $_ckey {
						when /^timeout$/ {
							$timeout = $content.<timeout>;
						}
						when /^dispatch_override$/ {
							$dispatch = $content.<dispatch_override>;
						}
					}
				}
			}
		}
		if $timeout {
			if $test {
				$dispatch = 'dispatch_DCHANNEL_TEST';
				$destination = 'test_timeout';
			}
			## NOTE: the timeout promise is set with the dispatch option/action
			my $emit_key = self._mess-enqueue($timeout,$dchannel_id,$dispatch,$destination,$test_message);
			
			## trigger sync reactor
			$!sync_supplier.emit($emit_key);
			
		} else {
			if $test {
				$dispatch = 'dispatch_DCHANNEL_TEST';
				$destination = 'test_call';
			}
			my $emit_key = self._mess-enqueue($dispatch,$destination,$test_message);

			## trigger async reactor
			$!async_supplier.emit($emit_key);
		}
		return;
	}
	if $*poe6_debug {
		$!admin_helper.__goto_die( 
			file => $?FILE, 
			class => ::?CLASS.^name, 
			method => &?ROUTINE.name, 
			line => $?LINE, 
			why => "DCHANNEL config destination is corrupted for dchannel[$dchannel_id]", 
			App_die_on_status_error => $*App_die_on_status_error,
		);
	}
	return Nil;
  }

  method link_kernel( $kernel! ) {
	$!POE6-KERNEL = $kernel;
  }
  
  method dispatch(Str $event, *@args) {
    die 'Please override &dispatch in your subclass of POE6::Session.';
  }

  method delay(Str $event, Int $timeout, *@args) {
	$!POE6-KERNEL.delay( self, $event, $timeout, @args );
	return True;
  }
  method yield( Str $event, *@args) {
	$!POE6-KERNEL.yield( self, $event, @args );
	return True;
  }
  method post( Str $event, *@args) {
	my $r = $!POE6-KERNEL.post( self, $event, @args );
	return $r;
  }

  multi method _mess-enqueue(Str $dispatch!,$destination!,$message,Str $responder?) {
    my $key = now;
	my $h = {destination => $destination, dispatch => $dispatch, message => $message };
	if $responder { $h.push: ( responder => $responder ) }
    %!async_mess.push: ( $key => $h );
	return $key;
  }
  multi method _mess-enqueue(Int $timeout!,Int $dchannel_id!,Str $dispatch!,$destination!,$message,Str $responder?) {
    my $key = now;
	if $responder { say "[mess-enqueue(sync)] responder-in[$responder]"; }
	my $h = {dchannel_id => $dchannel_id, destination => $destination, dispatch => $dispatch, timeout => $timeout, message => $message };
	if $responder { $h.push: ( responder => $responder ) }
    %!sync_mess.push: ( $key => $h );
	return $key;
  }


  method !async-react( :$key! ) {
    for %!async_mess.kv -> $_key, $content {
      if $_key ~~ /$key/ and $content ~~ Hash {
		my $session;
		my $dispatch;
		my $destination = '';
		my $mess;
		for keys $content -> $key {
			given $key {
				when /^dispatch$/ {
					$dispatch = $content.<dispatch>;
				}
				when /^message$/ {
					$mess = $content.<message>;
				}
				when /^destination$/ {
					$destination = $content.<destination>;
				}
			}
		}
		if $destination {
			my &code = {
				my $result := self."$dispatch"(destination => $destination, message => $mess);
				$result;
			}
			Promise.start( &code );
		}
		else {
			say "[async-react] REAL ERROR NO dispatch[$dispatch] destination [$destination]";
		}
		
		## clear contents
		for $content.kv -> $_k, $c {
			$content{$_k}:delete;
		}

	  }
	}
	
	## remove keyed info from events hash - done.
	%!async_mess{$key}:delete;
  }
  
  method !sync-react( :$key! ) {
    for %!sync_mess.kv -> $_key, $content {
		if $_key ~~ /$key/ and $content ~~ Hash {
			my ($dchannel_id,$dispatch,$timeout);
			my $responder = $!DCHANNEL_RESPONDER; #'send_back_on_dchannel'
			my $destination = '';
			my $mess;
			for keys $content -> $key {
				given $key {
					when /^dispatch$/ {
						$dispatch = $content.<dispatch>;
					}
					when /^message$/ {
						$mess = $content.<message>;
					}
					when /^destination$/ {
						$destination = $content.<destination>;
					}
					when /^timeout$/ {
						$timeout = $content.<timeout>;
					}
					when /^dchannel_id$/ {
						$dchannel_id = $content.<dchannel_id>;
					}
				}
			}
			if $destination {
				my $token_key = now;
				%!DCHANNEL_TOKEN_MAPPER.push: ($token_key => $dchannel_id);
				my %def_mess = ( i_mess => 0, mess => 'NOP', a_mess => Nil, h_mess => Nil );
				my &code;

				if $dispatch or $responder {
					if !$responder { $responder = $!DCHANNEL_RESPONDER; }
					&code = {
						my $result := self.waitontoken(
											token_key => $token_key,
											destination => $destination,
											dispatch => $dispatch,
											responder => $responder,
											timeout => $timeout,
											datakey => $key,
											def_message => %def_mess,
											);
						$result;
					}
				} else {
					&code = {
						my $result := self.waitontoken($token_key,$destination,$timeout,$key,%def_mess);
						$result;
					}
				}
				Promise.start( &code );
			}
			else {
				say "[sync-react] REAL ERROR NO destination option [$destination] on channel id[$dchannel_id]";
			}
		
			## clear contents
			for $content.kv -> $_k, $c {
				$content{$_k}:delete;
			}

		}
	}
	## remove keyed info from events hash - done.
	%!sync_mess{$key}:delete;

  }

  multi method waitontoken($token_key!,$destination!,$timeout!,$datakey?,%mess?) {
	if !$timeout { return Nil; }
	my $dispatch = $!DCHANNEL_DISPATCH; #'dispatch_dchannel'
	my $responder = $!DCHANNEL_RESPONDER; #'send_back_on_dchannel'
	if %mess !~~ Hash or %mess.elems < 1 {
		%mess = ( i_mess => 0, mess => "NOP" );
	}
	self.waitontoken(token_key => $token_key, destination => $destination, dispatch => $dispatch, timeout => $timeout, responder => $responder, datakey => $datakey, def_message => %mess);
  }

  multi method waitontoken(:$token_key!,:$dispatch!,:$destination!,:$timeout = 0,:$responder!,:$datakey?,:%ref_message?) {
	%!DCHANNEL_TOKENS{$token_key} = 1;
	start {
		self.checkpoint(token_key => $token_key, dispatch => $dispatch, destination => $destination, responder => $responder, datakey => $datakey, ref_message => item(%ref_message) );
	}
	if $timeout {
		my $status_message = { i_mess => 0, mess => 'timed out' };
		Promise.in($timeout).then: { self.checkpoint(token_key => $token_key, responder => $responder, status_message => $status_message ); }
	}
	return;
  }

  ## NOTE on the argument list for multi methods
  ##   the required list (!) for named variable must be different between methods,
  ##   otherwise, only the first method loaded will be called.
  multi method checkpoint(:$token_key!, :$responder!, :$status_message!) {
	if %!DCHANNEL_TOKENS{$token_key} == 1 {
		%!DCHANNEL_TOKENS{$token_key} = 0;
		self."$responder"(token_key => $token_key, message => $status_message);
	} else {
		%!DCHANNEL_TOKENS{$token_key}:delete; # remove token...work is done
	}
	return;
  }

  multi method checkpoint(:$token_key!, :$dispatch!, :$destination!, :$responder!, :$datakey?, :$ref_message? ) {
	my $message = self."$dispatch"(destination => $destination, datakey => $datakey, message => $ref_message);
	if %!DCHANNEL_TOKENS{$token_key} == 1 {
		%!DCHANNEL_TOKENS{$token_key} = 0;
		self."$responder"(token_key => $token_key, message => $message);
	} else {
		## possible bad relationship between timeout and session call
		## if $poe6_debug is turned on, the "bad" keys are held
		## Note, if you are using a token that is an ID value, this data may be overwritten
		if $*poe6_debug {
			%!DCHANNEL_TOKENS{$token_key}:delete; # remove token...work is done
		} else {
			%!DCHANNEL_TOKENS{$token_key} = now;
		}
	}
	return;
  }

  method send_back_on_dchannel(:$token_key, :$message) {
	## fetch dchannel info using $token_key
	my $dchannel_id = %!DCHANNEL_TOKEN_MAPPER{$token_key};
	%!DCHANNEL_TOKEN_MAPPER{$token_key}:delete; # clear token in mapper
	
	$!POE6-KERNEL.backcall_dchannel(dchannel_id => $dchannel_id, message => $message);
	
  }

  ## DEFAULT-SAMPLE dispatch_backcall methods.
  ## Override these methods within your session class, if using dedicated channels
  method dispatch_backcall(:$destination!, :$message!) {
	given $destination {
		when 'backcall' {
			my $me = &?ROUTINE.name;
		}
		when 'sample' {
			if $message ~~ Hash {
				my $backmessage = {i_mess => Nil, mess => '', a_mess => Nil, h_mess => Nil};

				## extract message data
				my ($i_mess,$mess,$a_mess,$h_mess);
				for keys $message -> $key {
					given $key {
						when /^i_mess$/ {
							$i_mess = $message.<i_mess>;
						}
						when /^mess$/ {
							$mess = $message.<mess>;
						}
						when /^a_mess$/ {
							$a_mess = $message.<a_mess>;
						}
						when /^h_mess$/ {
							$h_mess = $message.<h_mess>;
						}
					}
				}

				## do stuff

				return $backmessage;
			}
		}
	}
  }
  
  ## SAMPLE dispatch_dchannel methods.
  ## Override these methods within your session class, if using dedicated channels
  method dispatch_dchannel(:$destination!, :$message!, :$datakey?) {
	given $destination {
		when 'new_call' {
			my $me = &?ROUTINE.name;
			my $backmessage = {i_mess => Nil, mess => $me, a_mess => Nil, h_mess => Nil};
		}
		when 'sync_call' {
			my $me = &?ROUTINE.name;
			my $backmessage = {i_mess => 1, mess => 'Call using Sync Messaging', a_mess => item($me), h_mess => Nil};
			return $backmessage;
		}
		when $!DCHANNEL_RESPONDER {
			if $message ~~ Hash {
				my $backmessage = {i_mess => Nil, mess => '', a_mess => Nil, h_mess => Nil};

				## extract message data
				my ($i_mess,$mess,$a_mess,$h_mess);
				for keys $message -> $key {
					given $key {
						when /^i_mess$/ {
							$i_mess = $message.<i_mess>;
						}
						when /^mess$/ {
							$mess = $message.<mess>;
						}
						when /^a_mess$/ {
							$a_mess = $message.<a_mess>;
						}
						when /^h_mess$/ {
							$h_mess = $message.<h_mess>;
						}
					}
				}

				## do stuff

				return $backmessage;
			}
		}
	}
  }

  ## TEST methods to check if the dedicated channel is configured
  method dispatch_DCHANNEL_TEST(:$destination!, :$message!, :$datakey?) {
	given $destination {
		when 'new_call' {
			my $backmessage = {i_mess => Nil, mess => '', a_mess => Nil, h_mess => Nil};
		}
		when 'test_call' {
			my $backmessage = {i_mess => Nil, mess => '', a_mess => Nil, h_mess => Nil};
			my $me = &?ROUTINE.name;
			say "[dispatch_dchann] sess-ctr["~self.SESSION_CTR~"] TEST_CALL in-dispatch[$me] destination[$destination] message["~$message.gist~"]";
		}
		when 'test_timeout' {
			my $backmessage = {i_mess => Nil, mess => 'Test Call for Sync Messaging', a_mess => Nil, h_mess => Nil};
			my $me = &?ROUTINE.name;
			say "[dispatch_dchann] sess-ctr["~self.SESSION_CTR~"] TEST_CALL in-dispatch[$me] destination[$destination] message["~$backmessage.gist~"]";
			return $backmessage;
		}
		when 'backcall' {
			my $me = &?ROUTINE.name;
		}
	}
  }

  ## END of POE6::Session role
 }


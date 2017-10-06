## Tiny examples

use POE6::Tiny;
use POE6::MySession;

## show a start
say "POE6-Tiny says hello!";

#E Create the global POE::Kernel object.
our $POE::Kernel = POE6::Kernel.new;

#E Set a global toggle variable 
# (this does not do much yet)
$*App_die_on_status_error = 1;

## Create a session using the MySession sample module/package
my $session = MySession.new;

## Basic forms of post/yield/delay method calls:
## {kernel}.post( $session, $event, @args );
## ...if using a registered session:
## {session}.post( $event, @args );
## The session's dispatch method's 'given' conditional must include
## a matching 'event' option -> The end instructions of the callback.

## Execute a 'post' call to the kernel with the session object
## Note that this call has an implicit sync'ed return,
## so the result can be printed to the screen.
say $POE::Kernel.post($session, "say_hello", "Poe Poe");

## Create another session
my $session2 = MySession.new;

## Execute a 'yield' call to the kernel with the session object
say $POE::Kernel.yield($session2, "say_hello", "Poe Poe too");
	## Note: the session callback will print the arg [Poe Poe too] to 
	## the screen, but the 'yield' call will return True. So the
	## above statement will print "True" when result returns.
	

## Create yet another session
my $session3 = MySession.new;

## Add the session to the kernel environment
$POE::Kernel.add_session( $session3 );

## We can now do a post/yield/delay method call to the session object

## Execute a 'delay' call to the kernel with the session object
say $session3.delay("say_hello", 3, "Poe Poe twee");
	## Note: the session callback will print the arg [Poe Poe twee] to 
	## the screen, but the 'delay' call will return True.
	## The 'delay' method has the form 
	## {session}.post( $event, $timeout, @args );
	
## Also can...
## Create a session with the POE::Kernel as an initial argument
my $session4 = MySession.new( poe_kernel => $POE::Kernel );


####
## Other stuff
####

## add aliases
$session4.session_alias(alias => 'tweedle');

## and set messaging option. Enables reactor routines within the session object.
$session4.set_session_messaging(1);

my $session5 = MySession.new( poe_kernel => $POE::Kernel, alias => 'dee', set_session_messaging => 1 );

## some stuff to pass around
my @a = (a,b);
my %h = (a => 1, b => 2);
my $message = { i_mess => 1, mess => 'dchannel message', a_mess => item(@a), h_mess => item(%h) };
	
## register a dedicated channel. It returns the dchannel_id used for calling the dchannel.
my $dchann_id = $POE::Kernel.register_dchannel( session_from_key => 'tweedle', session_to_key => 'dee', destination => 'new_call' );

## send a message (new_call should print a default message to the screen).
$POE::Kernel.dchannel_message( dchannel_id => $dchann_id, message => $message );

## a 'test' option is available to check that the standard methods still work...
my $test = 1;
sleep 2;
$POE::Kernel.dchannel_message( $dchann_id, $test, $message );


## register a dedicated channel with a response and timeout. If the timeout is 0, then the response will be processed
## whenever the message is eventually sent. The timeout provides an indication of process failure.
my $dchann2_id = $POE::Kernel.register_dchannel( 
					session_from_key => 'tweedle',
					session_to_key => 'dee', 
					destination => 'sync_call',
					responder => 'send_back_on_dchannel',
					await_response => 1,
					timeout => 2,
					);
					
## send a message on dchannel #2 
$POE::Kernel.dchannel_message( dchannel_id => $dchann2_id, message => $message );

sleep 3;
## remove dchannel #2
say $POE::Kernel.remove_dchannel( $dchann2_id );


## That's all!

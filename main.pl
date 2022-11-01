#/usr/bin/perl

use warnings;
use strict;

use IO::Select;
use IO::Handle;
use Socket;
use POSIX;

sub main ()
{
	srand(time());

 	my $configurationServerCore =	
	{
		localServerHost		=> 'localhost',
		localServerPort		=> '5555',
		remoteTargetAddr	=> 'chat.idx.pl',
		remoteTargetPort 	=> '6667',
		lastCheckTimeout 	=>	time(),
		isReadyToCheckAlive	=> 0,
	};

	socket( $configurationServerCore->{ localServerSocket }, AF_INET, SOCK_STREAM, getprotobyname('TCP') ) or die $!;	
	setsockopt( $configurationServerCore->{ localServerSocket }, SOL_SOCKET, SO_REUSEADDR, 1 ) or die $!;
	bind( $configurationServerCore->{ localServerSocket },  sockaddr_in(
		$configurationServerCore->{ localServerPort }, inet_aton( $configurationServerCore->{ localServerHost } ) ) ) or die $!;
	listen( $configurationServerCore->{ localServerSocket }, SOMAXCONN ) or die $!;

	$configurationServerCore->{ localServerSocket }->autoflush(1);

 	$configurationServerCore->{ selectInterfaceOO } = IO::Select->new();
 	$configurationServerCore->{ selectInterfaceOO }->add( $configurationServerCore->{ localServerSocket } );

	mainLoop($configurationServerCore);
	close($configurationServerCore->{ localServerSocket });

 	return;
}

sub mainLoop 
{
 	my $configurationServerCore = shift(@_);
 	my $tempListSockets			= {};
 	my $remoteListSockets 		= {};
 	my $clientListSockets 		= {};
 	my @tempArray;
 	my $socketFromIOSelectList;

 	while (1)
 	{		
		checkTimeoutAllSockets($configurationServerCore) if ((time() - $configurationServerCore->{ lastCheckTimeout} ) > 60);
		checkAliveAllSockets($configurationServerCore) if $configurationServerCore->{ isReadyToCheckAlive };

 		foreach $socketFromIOSelectList ($configurationServerCore->{ selectInterfaceOO }->can_read()) 
 		{
 			if ($socketFromIOSelectList == $configurationServerCore->{ localServerSocket })
 			{
 				# [CLIENT CONNECTION]
 				$configurationServerCore->{rand1} = int(rand(20000000));
 				accept($tempListSockets->{$configurationServerCore->{rand1}}, $configurationServerCore->{ localServerSocket });

 				# [TARGETSERVER CONNECTION]
 				$configurationServerCore->{rand2} = int(rand(20000000));
 				socket($tempListSockets->{$configurationServerCore->{rand2}}, AF_INET, SOCK_STREAM, getprotobyname('TCP'));
 				connect($tempListSockets->{$configurationServerCore->{rand2}}, sockaddr_in($configurationServerCore->{ remoteTargetPort }, inet_aton($configurationServerCore->{ remoteTargetAddr })));

 				# [CREATE DATA IN HASH]
 				$configurationServerCore->{ isSocketAlive }->{ $tempListSockets->{$configurationServerCore->{rand1}} } = 1;
 				$configurationServerCore->{ isSocketAlive }->{ $tempListSockets->{$configurationServerCore->{rand2}} } = 1;

 				$configurationServerCore->{ connectedSocketsList }->{ $tempListSockets->{$configurationServerCore->{rand1}} } = 'client';
 				$configurationServerCore->{ connectedSocketsList }->{ $tempListSockets->{$configurationServerCore->{rand2}} } = 'server';

 				$tempListSockets->{$configurationServerCore->{rand1}}->autoflush(1);
 				$tempListSockets->{$configurationServerCore->{rand2}}->autoflush(1);

 				$configurationServerCore->{ selectInterfaceOO }->add( $tempListSockets->{$configurationServerCore->{rand1}});
 				$configurationServerCore->{ selectInterfaceOO }->add( $tempListSockets->{$configurationServerCore->{rand2}});

 				$remoteListSockets->{$tempListSockets->{$configurationServerCore->{rand1}}} = $tempListSockets->{$configurationServerCore->{rand2}};
 				$clientListSockets->{$tempListSockets->{$configurationServerCore->{rand2}}} = $tempListSockets->{$configurationServerCore->{rand1}};				
 			}	
 			else
 			{
 				receiveDataFromSocket($socketFromIOSelectList, $configurationServerCore);
 				if ($configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList } && length($configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList }) > 0)
 				{
 					if ($configurationServerCore->{ brokenLineRest }->{ $socketFromIOSelectList })
 					{
 						$configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList } = $configurationServerCore->{ brokenLineRest }->{ $socketFromIOSelectList } . $configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList };
 					}

 					if ((substr $configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList }, (length($configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList })-1)) ne "\n")
					{
						$configurationServerCore->{ brokenLineRest }->{ $socketFromIOSelectList } = (split("\n", $configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList }))[-1];
                 	}
					else
					{
						$configurationServerCore->{ brokenLineRest }->{ $socketFromIOSelectList } = undef;
					}

 					@tempArray = split("\n", $configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList });
 					if ((substr $configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList }, (length($configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList })-1)) ne "\n")
 					{
 						pop(@tempArray);
 					}
 					foreach (@tempArray)
 					{
 						if ($configurationServerCore->{ connectedSocketsList }->{ $socketFromIOSelectList } eq 'client')
 						{
 							$configurationServerCore->{ lastLineFromClient } = $_ . "\n";
							sendDataToSocket($remoteListSockets->{ $socketFromIOSelectList }, $configurationServerCore->{ lastLineFromClient }, $configurationServerCore);
 						}
 						elsif ($configurationServerCore->{ connectedSocketsList }->{ $socketFromIOSelectList } eq 'server')
 						{
 							$configurationServerCore->{ lastLineFromServer } = $_ . "\n";
							sendDataToSocket($clientListSockets->{ $socketFromIOSelectList }, $configurationServerCore->{ lastLineFromServer }, $configurationServerCore);
 						}						
 					}
 				}
 				else
 				{
					delete $remoteListSockets->{ $socketFromIOSelectList };
					delete $clientListSockets->{ $socketFromIOSelectList };

 					$configurationServerCore->{ isSocketAlive }->{ $socketFromIOSelectList } = 0;	
 					$configurationServerCore->{ isReadyToCheckAlive } = 1;			
 					next;
 				}
 			}
 		}	
 	}
 	return;
}

sub checkAliveAllSockets
{
	my $configurationServerCore	= shift(@_);
	my @listAviableSockets;

	@listAviableSockets = $configurationServerCore->{ selectInterfaceOO }->handles();
	shift(@listAviableSockets);

	foreach ( @listAviableSockets )
	{
		unless($configurationServerCore->{ isSocketAlive }->{$_})
		{
			$configurationServerCore->{ selectInterfaceOO }->remove($_);
			close($_);
			delete $configurationServerCore->{ brokenLineRest }->{$_};
			delete $configurationServerCore->{ connectedSocketsList }->{$_};
			delete $configurationServerCore->{ handyBufferFromSocket }->{$_};
			delete $configurationServerCore->{ isSocketAlive }->{$_};
			delete $configurationServerCore->{ lastActiveTimeSocket }->{$_};
		}
	}
	$configurationServerCore->{ isReadyToCheckAlive } = 0;

 	return;
}

sub checkTimeoutAllSockets
{
 	my $configurationServerCore	= shift(@_);
 	my @listAviableSockets;

 	@listAviableSockets = $configurationServerCore->{ selectInterfaceOO }->handles();
 	shift(@listAviableSockets);

 	foreach (@listAviableSockets)
 	{
 		if ($configurationServerCore->{ lastActiveTimeSocket }->{$_})
 		{
 			if ((time() - $configurationServerCore->{ lastActiveTimeSocket }->{$_}) > 150)
 			{
 				$configurationServerCore->{ isSocketAlive }->{$_} = 0;
 				$configurationServerCore->{ isReadyToCheckAlive } = 1;
 			}
 		}
 	}
	$configurationServerCore->{ lastCheckTimeout } = time();

 	return;
}

sub sendDataToSocket
{
 	my $socketFromIOSelectList		= shift(@_);
 	my $buforFromSocket				= shift(@_);
 	my $configurationServerCore		= shift(@_);

 	eval
 	{
 		if ($configurationServerCore->{ isSocketAlive }->{ $socketFromIOSelectList })
 		{
 			send($socketFromIOSelectList, "" . join(" ", split(/\s/, $buforFromSocket)) . "\r\n", 0) or die $!;
 		}
 	};
 	if ($@)
 	{
 		$configurationServerCore->{ isSocketAlive }->{$socketFromIOSelectList} = 0;
 		$configurationServerCore->{ isReadyToCheckAlive } = 1;
 	}
 	else
 	{
 		$configurationServerCore->{ lastActiveTimeSocket }->{ $socketFromIOSelectList } = time() if ($socketFromIOSelectList);
 	}
 	return 0;
}

sub receiveDataFromSocket
{
 	my $socketFromIOSelectList		= shift(@_);
 	my $configurationServerCore		= shift(@_);

 	eval
 	{
		recv($socketFromIOSelectList, $configurationServerCore->{ handyBufferFromSocket }->{ $socketFromIOSelectList }, POSIX::BUFSIZ, 0) 
			if ($configurationServerCore->{ isSocketAlive }->{ $socketFromIOSelectList });
 	};
 	if ($@)
 	{
 		$configurationServerCore->{ isSocketAlive }->{ $socketFromIOSelectList } = 0;
 		$configurationServerCore->{ isReadyToCheckAlive } = 1;
 	}
 	return 0;
}

main();
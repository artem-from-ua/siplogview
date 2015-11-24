#!/usr/bin/perl

#----------------------------------------------------------------------------------
#
#  Parser for the PortaSIP log files to extract all messages with the same Call-ID
#  and represent the data in convenient form.
#
#  $Id: siplogview.pl,v 1.2 2006/05/19 13:04:13 tutanhamon Exp $
#
#  Type 'siplogview.pl --help' to view the command options and usage.
#
#----------------------------------------------------------------------------------
#
#  All company and product names are treadmarks or registred trademarks of the 
#  respective owners with which they are associated.
#
#----------------------------------------------------------------------------------
#
#  This script is distributed under the conditions of BSD-like Open Source license:
#
#
#  Copyright (C) 2004, 2005, 2006 Artem Naluzhny. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
# 
#     THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#     ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#     IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#     ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
#     FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#     DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#     OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#     HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#     OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#     SUCH DAMAGE.
#
#----------------------------------------------------------------------------------

use Getopt::Long;
use strict;

$| = 1;

my $FieldWidth = 29;
my $MessageLinesLimit = 500;
my $MessagesLimit = 1000;
my $UAsLimit = 20;

(my $_Version = '$Revision: 1.2 $') =~ s/^[\$]Revision: (.*) \$$/$1/;
my $_HelpScreen = "  PortaSIP log files parser.

  USAGE

    siplogview.pl [-h|--help]

    siplogview.pl [--log] CALL-ID
                  [-c] [-t] [-l MESSAGE_LINES_LIMIT]

    siplogview.pl --diagram -a SIP_NODE_IP CALL-ID
                  [-i] [-s] [-w WIDTH]
                  [-l LOG_LINES_LIMIT] [-m MESSAGES_LIMIT]
		  [-u USER_AGENTS_LIMIT]

    siplogview.pl --mixed -a SIP_NODE_IP CALL-ID
                  [-c] [-i] [-s] [-t] [-v] [-w WIDTH]
                  [-l LOG_LINES_LIMIT] [-m MESSAGES_LIMIT]
		  [-u USER_AGENTS_LIMIT]

    siplogview.pl --html -a  SIP_NODE_IP CALL-ID
                  [-c] [-i] [-h] [-s] [-t] [-v] [-w WIDTH]
                  [-l LOG_LINES_LIMIT] [-m MESSAGES_LIMIT]
		  [-u USER_AGENTS_LIMIT]

  OPTIONS

  Mode options:
  
    -h
    --help
            This help screen.

    --log
            Parse sip.log format stream from STDIN and output the messages
	    with CALL-ID only (the same as 'siplogview.pl CALL-ID').

    --diagram
            Parse sip.log format stream from STDIN and output the SIP call
            diagram for the CALL-ID. The '-a' parameter should be present.
    
    --mixed
            Output the '--log' and then the '--diagram' of the call. The '-a'
	    parameter should be present.

    --html
            Parse sip.log format stream from STDIN and generate a HTML
	    document with the call diagram and the call messages. The '-a'
	    parameter should be present.


  Call identifying options:

    -a SIP_NODE_IP
            IP address of the PortaSIP server (or specific PortaSIP
	    node) in decimal dot separated format. Is used with
	    '--diagram' and '--html' options.

    CALL-ID
            SIP Call-ID of the call. Perl regular expression is allowed
	    (it is usually used in '--log' mode).


  Output format options:

    -c
    --no-content
            Eliminate content part of SIP messages (used with '--log' or 
	    '--html' options).

    -i
    --no-dialog-id
            Do not print SIP dialog IDs on the diagram (used with '--diagram'
	    or '--html' options).

    -h
    --no-header
            Do not generate <HEAD> part of HTML document (used with '--html'
	    option).

    -s
    --no-cseq
            Do not print values of 'CSeq:' header on the diagram (used with 
	    '--diagram' or '--html' options).

    -t
    --no-tabs
            Do not prepend SIP messages with the '\\t' (TAB) char in '--log'
	    or '--html' output.

    -v
            Try to obtain more info about the call (used with '--diagram' or 
	    '--html' options). The script parses 'portasip.conf' file of the
	    PortaSIP node and tries to connect to master database.

    -w WIDTH
            Change the dafault number of charaters ($FieldWidth) between the
	    vertical lines on the diagram. Is used with '--diagram' or
	    '--html'. Min. value: 7, recommended min. value: 10 (with '-i'
	    and '-s' options).


  Script limits options:

    -l MESSAGE_LINES_LIMIT
            Change the default limit ($MessageLinesLimit) of lines in a separate
	    SIP message.

    -m MESSAGES_LIMIT
            Change the default limit ($MessagesLimit) of processing messages in a
	    corresponding to the given Call-ID.

    -u USER_AGENTS_LIMIT
            Change the default limit ($UAsLimit) of SIP user agents on diagrams
	    (used with '--diagram' or '--html' options).


  EXAMPLES

    --log

      siplogview.pl \"11352465-cda78\@10.0.0.5\" < sip.log
      siplogview.pl --log \"11352465-cda78\@10.0.0.5\" < sip.log
      tail -f sip.log | siplogview.pl \".*\@10.0.0.5\"

    --diagram

      siplogview.pl --diagram -a 10.1.200.1 \"115-cda78\@10.0.0.5\" < sip.log

    --html

      siplogview.pl --html -a 10.1.200.1 \"115-cda78\@10.0.0.5\" < sip.log

";

my $_MessageLinesLimit = "PARSER ERROR: The message exceeds MESSAGE_LINES_LIMIT lines limit (see '-l' option).\n";
my $_MessagesLimit = "PARSER ERROR: Message number exceeds MESSAGES_LIMIT limit (see '-m' option).\n";


# Command-line options defaults:

my $Option_help;

my $Mode_log;
my $Mode_diagram;
my $Mode_html;

my $Call_ID;
my $PortaSIP_IP;

my $Tab;
my $NoTabs;
my $TZ_shift;
my $TZ_name;
my $NoCSeq;
my $NoDialogID;
my $i_env;
my $AAA_ip;


my %Host;
my @LogEntry;
my @DialogID;
my @MDialogID;

#----------------------------------------------------------------------------------------
sub Without_Diagram {

my $Messages = 0;

while (<STDIN>) {
    s/^([^\r]*)\r?$/$1/; # cut trailing '\r'

    if (/^[^\/]+\/($Call_ID)\// or /^.*[^a-zA-Z0-9.!%*_+`'~(){}?<>\-]($Call_ID)[^a-zA-Z0-9.!%*_+`'~(){}?<>\-]*/) { # is there a call-id marked record?
        my $MessageLines = 1;

	$Messages++ <= $MessagesLimit or die $_MessagesLimit;
        print;

        # is there following AAA request/reply message?
        if (/: (sending AAA request.*|sending Acct .*|AAA request accepted\, processing response|AAA request rejected\, processing response):$/) {
	    while (<STDIN>) { # extracting AAA request/reply message
	        s/^\t?([^\t\r]*)\r?$/$1/; # cut heading '\t' and trailing '\r'
	        $MessageLines++ <= $MessageLinesLimit or die $_MessageLinesLimit;

         	if (/^$/) {
                    print;
		    last;
		} else {
                    print "$Tab$_";
		}
	    }
	}

    # is there following message has been sent/received
    } elsif (/^[^\/]+\/GLOBAL\/.*(SENT message to|SENDING message to|RECEIVED message from) .*:/) {
        my $Message = $_;     # temporary buffer for the message
	my $MessageLines = 1; # number of lines in the current message

        my $Is_our_Call_ID = 0;
        my $Content_Length = 0;

        while (<STDIN>) { # extracting a message
	    s/^\t?([^\t\r]*)\r?$/$1/; # cut heading '\t' and trailing '\r'

            if (/^Call-ID: *($Call_ID)$/i) { # check if the message is with our Call-ID?
                $Is_our_Call_ID = 1;

            } elsif (/^Content-Length: *([0-9]+)$/i) { # check if there is following message content
	        $Content_Length = $1;

	    } elsif (/^$/) {
                if ($Content_Length > 0) {
                    $Message .= "$Tab\n";
                    $MessageLines++ <= $MessageLinesLimit or die $_MessageLinesLimit;

                    while (<STDIN>) { # extracting the message content
	  	        s/^\t?([^\t\r]*)\r?$/$1/; # cut heading '\t' and trailing '\r'

          		last if (/^$/);

                        $Message .= "$Tab$_";
	                $MessageLines++ <= $MessageLinesLimit or die $_MessageLinesLimit;
		    }
		}
	        last;
	    }

            $Message .= "$Tab$_";
	    $MessageLines++ <= $MessageLinesLimit or die $_MessageLinesLimit;

        }

	if ($Is_our_Call_ID) {
	    $Messages++ <= $MessagesLimit or die $_MessagesLimit;
	    print "$Message\n" if ($Is_our_Call_ID);
	}
    }
}
}

#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------
sub With_Diagram {

my $H323_Conf_ID;
my $Date;

#---------------------------------------------------------------------------------
sub String2JS {
    my $String = shift @_;

    $String =~ s/\'/\\\'/g;
    $String =~ s/\n/\\n/g;
    $String =~ s/&/&amp;/g;
    $String =~ s/</&lt;/g;

    return $String;
}

#---------------------------------------------------------------------------------
sub GetDialogID {
  my %Param = @_;

  return '??' if ($Param{'CallID'} eq '' or $Param{'FromTag'} eq ''); # something wrong with the SIP message

  
  my $MajorDialogID;
  my $MajorDialogIDIndex;
  for (my $DialogIDIndex = 0; $DialogIDIndex <= $#DialogID; $DialogIDIndex++) {
    if ($Param{'CallID'} eq $DialogID[$DialogIDIndex]{'CallID'} and $Param{'FromTag'} eq $DialogID[$DialogIDIndex]{'FromTag'}) {
      $MajorDialogID = chr(ord('A') + $DialogIDIndex);
      $MajorDialogIDIndex = $DialogIDIndex;
      last;
    } elsif ($Param{'CallID'} eq $DialogID[$DialogIDIndex]{'CallID'} and $Param{'ToTag'} eq $DialogID[$DialogIDIndex]{'FromTag'}) {
      $MajorDialogID = chr(ord('A') + $DialogIDIndex);
      $MajorDialogIDIndex = $DialogIDIndex;
      last;
    }
  }

  if (not defined $MajorDialogID) {
    $DialogID[$#DialogID +1] = {
      'CallID' => $Param{'CallID'},
      'FromTag' => $Param{'FromTag'},
      'MinorDialogs' => 0};
    $MajorDialogID = chr(ord('A') + $#DialogID);
    $MajorDialogIDIndex = $#DialogID;
  }

#-----------------
  my $MinorDialogID = '?';
  
  if (defined $Param{'ToTag'} and $Param{'ToTag'} ne '') {
    for (my $DialogIDIndex = 0; $DialogIDIndex <= $#MDialogID; $DialogIDIndex++) {
      if ($Param{'CallID'} eq $MDialogID[$DialogIDIndex]{'CallID'} and $Param{'FromTag'} eq $MDialogID[$DialogIDIndex]{'FromTag'} and $Param{'ToTag'} eq $MDialogID[$DialogIDIndex]{'ToTag'}) {
        $MinorDialogID = chr(ord('a') + $MDialogID[$DialogIDIndex]{'MinorDialogs'});
        last;
      } elsif ($Param{'CallID'} eq $MDialogID[$DialogIDIndex]{'CallID'} and $Param{'ToTag'} eq $MDialogID[$DialogIDIndex]{'FromTag'} and $Param{'FromTag'} eq $MDialogID[$DialogIDIndex]{'ToTag'}) {
        $MinorDialogID = chr(ord('A') + $MDialogID[$DialogIDIndex]{'MinorDialogs'});
        last;
      }
    }

    if ($MinorDialogID eq '?') {
      $MDialogID[$#MDialogID +1] = {
        'CallID' => $Param{'CallID'},
        'FromTag' => $Param{'FromTag'},
        'ToTag' => $Param{'ToTag'},
        'MinorDialogs' => $DialogID[$MajorDialogIDIndex]{'MinorDialogs'}};
      $MinorDialogID = chr(ord('a') + $MDialogID[$#MDialogID]{'MinorDialogs'});
      $DialogID[$MajorDialogIDIndex]{'MinorDialogs'}++;
    }
  }

  return $MajorDialogID.$MinorDialogID;
}

#---------------------------------------------------------------------------------
sub CompleteDialogs {

return;

for (my $LogEntryIndex = 0; $LogEntryIndex <= $#LogEntry; $LogEntryIndex++) {
  if ($LogEntry[$LogEntryIndex]{'CSeq'} ne '' and $LogEntry[$LogEntryIndex]{'DialogID'} eq '') {

#   debug
#    print "\n1{".$LogEntry[$LogEntryIndex]{'CSeq'}.'}  2{'.$LogEntry[$LogEntryIndex]{'ToIP'}.'}  2{'.$LogEntry[$LogEntryIndex]{'From'}.'}  3{'.$LogEntry[$LogEntryIndex]{'FromTag'}.'}  4{'.$LogEntry[$LogEntryIndex]{'To'}.'}  5{'.$LogEntry[$LogEntryIndex]{'ToTag'}."}\n";

    for (my $LogEntryIndex2 = $LogEntryIndex +1; $LogEntryIndex2 <= $#LogEntry; $LogEntryIndex2++) {
#     debug
#      print '  --> 1{'.$LogEntry[$LogEntryIndex2]{'CSeq'}.'}  2{'.$LogEntry[$LogEntryIndex2]{'DialogID'}.'}  2{'.$LogEntry[$LogEntryIndex2]{'FromIP'}.'}  2{'.$LogEntry[$LogEntryIndex2]{'From'}.'}  4{'.$LogEntry[$LogEntryIndex2]{'To'}."}\n";
      
      if ($LogEntry[$LogEntryIndex2]{'DialogID'} ne '' and
          $LogEntry[$LogEntryIndex]{'From'} eq $LogEntry[$LogEntryIndex2]{'From'} and
	  $LogEntry[$LogEntryIndex]{'To'} eq $LogEntry[$LogEntryIndex2]{'To'} and
	  $LogEntry[$LogEntryIndex]{'CSeq'} eq $LogEntry[$LogEntryIndex2]{'CSeq'} and

          (($LogEntry[$LogEntryIndex]{'ToIP'} eq $LogEntry[$LogEntryIndex2]{'FromIP'} and
            $LogEntry[$LogEntryIndex]{'FromIP'} eq $LogEntry[$LogEntryIndex2]{'ToIP'}) or
	   ($LogEntry[$LogEntryIndex]{'ToIP'} eq $LogEntry[$LogEntryIndex2]{'ToIP'} and
            $LogEntry[$LogEntryIndex]{'FromIP'} eq $LogEntry[$LogEntryIndex2]{'FromIP'}))) {
        
	$LogEntry[$LogEntryIndex]{'DialogID'} = $LogEntry[$LogEntryIndex2]{'DialogID'};
        my $NewDialogID = $LogEntry[$LogEntryIndex]{'DialogID'};
	$LogEntry[$LogEntryIndex]{'Text'} =~ s/\( (.*)/\($NewDialogID $1/i;;
	last;
      }  
    }
#   debug
#    print "\n";
    if ($LogEntry[$LogEntryIndex]{'DialogID'} eq '') {
      $LogEntry[$LogEntryIndex]{'DialogID'} = '?';
      $LogEntry[$LogEntryIndex]{'Text'} =~ s/\( (.*)/\(\? $1/i;;
    }
  }
}
}


#---------------------------------------------------------------------------------
sub AddHost {
    my %HostParam = @_;
    my @Keys = keys %Host;

    if ($HostParam{'Name'} eq 'b2bua') {
        if (!defined $Host{'b2bua'}) {
	    $Host{'b2bua'} = {
	        'IP' => $PortaSIP_IP,
		'Order' => $#Keys+1,
		'Description' => 'PortaSIP'};
	}
    } elsif ($HostParam{'Name'} eq 'ser') {
        if (!defined $Host{'ser'}) {
	    $Host{'ser'} = {
	        'IP' => $PortaSIP_IP,
		'Order' => $#Keys+1,
		'Description' => 'PortaSIP'};
	}
    } elsif ($HostParam{'Name'} eq 'asterisk') {
        if (!defined $Host{'asterisk'}) {
	    $Host{'asterisk'} = {
	        'IP' => $PortaSIP_IP,
		'Order' => $#Keys+1,
		'Description' => 'PortaSIP'};
	}
    } elsif ($HostParam{'Name'} eq 'AAA') {
        if (!defined $Host{'AAA'}) {
	    $Host{'AAA'} = {
	        'IP' => '',
		'Order' => $#Keys+1,
		'Description' => 'PortaBilling'};
	}
    } elsif ($HostParam{'Name'} ne $PortaSIP_IP) {
        if (!defined $Host{$HostParam{'Name'}}) {
	    $Host{$HostParam{'Name'}} = {
		'Order' => $#Keys+1,
		'IP' => $HostParam{'Name'}};
	}
	if ($HostParam{'Description'} and !defined $Host{$HostParam{'Name'}}{'Description'}) {
	    $Host{$HostParam{'Name'}}{'Description'} = $HostParam{'Description'};
	}
    }
}

#---------------------------------------------------------------------------------
sub AddLogEntry {
    my %LogEntryParam = @_;

    $LogEntry[$#LogEntry +1] = {
        'Time' => $LogEntryParam{'Time'},
        'Type' => $LogEntryParam{'Type'},
        'FromIP' => defined $LogEntryParam{'FromIP'}?$LogEntryParam{'FromIP'}:'',
	'ToIP' => defined $LogEntryParam{'ToIP'}?$LogEntryParam{'ToIP'}:'',
        'From' => defined $LogEntryParam{'From'}?$LogEntryParam{'From'}:'',
	'To' => defined $LogEntryParam{'To'}?$LogEntryParam{'To'}:'',
        'FromTag' => defined $LogEntryParam{'FromTag'}?$LogEntryParam{'FromTag'}:'',
	'ToTag' => defined $LogEntryParam{'ToTag'}?$LogEntryParam{'ToTag'}:'',
	'CSeq' => defined $LogEntryParam{'CSeq'}?$LogEntryParam{'CSeq'}:'',
	'CallID' => $LogEntryParam{'CallID'},
	'DialogID' => defined $LogEntryParam{'DialogID'}?$LogEntryParam{'DialogID'}:'',
	'WarningFlag' => defined $LogEntryParam{'WarningFlag'}?$LogEntryParam{'WarningFlag'}:'',
	'SDPFlag' => defined $LogEntryParam{'SDPFlag'}?$LogEntryParam{'SDPFlag'}:'',
        'Text' => $LogEntryParam{'Text'}};
}

#---------------------------------------------------------------------------------
sub PrintDiagramHeader {
    if (defined $Mode_html) {
        my $Flag = 0;    
        print "diagram.document.write('<span class=\"background1\">PortaSIP </span>";
        foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
            printf ('<span class="background'.($Flag?1:2).'"> %-'.$FieldWidth.'.'.$FieldWidth.'s</span>', ($CurrentHost =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/)?'UA':$CurrentHost);
	    $Flag = !$Flag;
        }
        print "\\n');\n";

        $Flag = 0;
        print "diagram.document.write('<span class=\"background1\"> server  </span>";
        foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
            printf ('<span class="background'.($Flag?1:2).'"> %-'.$FieldWidth.'.'.$FieldWidth.'s</span>', defined $Host{$CurrentHost}{'IP'}?$Host{$CurrentHost}{'IP'}:'');
	    $Flag = !$Flag;
        }
        print "\\n');\n";

        $Flag = 0;
        print "diagram.document.write('<span class=\"background1\">  time   </span>";
        foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
            printf ('<span class="background'.($Flag?1:2).'"> %-'.$FieldWidth.'.'.$FieldWidth.'s</span>', $Host{$CurrentHost}{'Description'});
	    $Flag = !$Flag;
        }
        print "\\n');\n";
    } else {
        print "PortaSIP ";
        foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
            printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', ($CurrentHost =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/)?'UA':$CurrentHost);
        }
        print "\n";

        print " server  ";
        foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
            printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', defined $Host{$CurrentHost}{'IP'}?$Host{$CurrentHost}{'IP'}:'');
        }
        print "\n";

        print "  time   ";
        foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
            printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', $Host{$CurrentHost}{'Description'});
        }
        print "\n";    
    }
}
#----------------------------------------------------------------------------------------

if (defined $Mode_html) {
  print <<EOF;
<html>

<head>
    <title>siplogview :: Call-ID: $Call_ID</title>
    <meta name="Generator" content="$_Version">
</head>

<script language="JavaScript">
document.title+=" :: siplogview :: Call-ID: $Call_ID";
window.defaultStatus="";

function updateStatus(packet, mouseover) {
    if (mouseover) {
        parent.window.status="Packet #"+packet+". Click to show it.";
    } else {
        parent.window.status="";
    }
}

// Based on hints found in script by Martin Honnen <mahotrash\@yahoo.de>
// Available at http://www.faqts.com/knowledge_base/view.phtml/aid/13648
function moveToPacket(packet) {
    var coords = {x:0, y:0};
    var anchor = parent.frames["log"].document.anchors[packet];

    if (anchor.x || anchor.x==0 && anchor.y || anchor.y==0) {
        //coords.x = anchor.x;
        coords.y = anchor.y;
    } else { // I believe with modern browsers it should never reach this point
        while (anchor) {
            //coords.x += anchor.offsetLeft;
            coords.y += anchor.offsetTop;
            anchor = anchor.offsetParent;
        }
    }

    parent.frames["log"].scrollTo(coords.x, coords.y);                                                                         }
</script>

<script language="JavaScript">
function fill_frames() {

// start of bottom (log) frame
log.document.open();
log.document.write('<html><style type=text/css><!-- pre {font-family:monospace; font-size:11px; }body {margin:  1px; padding: 1px;} /--></style><body><pre>');

EOF
}

while (<STDIN>) {
    s/^([^\r]*)\r?$/$1/; # cut trailing '\r'
    
    if (/^([^ ]+ [^ ]+) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])\/($Call_ID)\/([^:[]+)[:[]/ or 
		/^([^ ]+ [^ ]+) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])\/(GLOBAL)\/([^:[]+)(?:\[[0-9]+\])?:.*[^a-zA-Z0-9.!%*_+`'~(){}?<>\-]($Call_ID)[^a-zA-Z0-9.!%*_+`'~(){}?<>\-]*/) { # is there a call-id marked record?
        my $Time = $2;
	my $LocalComponent = $4;
	
	my $MessagePrefix = '';
        my $Message = $_;
	
	if (!defined $Date) {
	    $Date = $1;
	}
	
	# is there following AAA request/reply message?
    if (/: (sending AAA request.*|sending Acct .*|AAA request accepted\, processing response|AAA request rejected\, processing response):$/) {
	    if (/: (sending AAA request|sending Acct ).*:$/) {
	        AddHost('Name' => $LocalComponent);
	        AddHost('Name' => 'AAA');
	        AddLogEntry(
		    'Time' => $Time, 
		    'Type' => 'direct/request', 
		    'FromIP' => $LocalComponent, 
		    'ToIP' => 'AAA');
	    } else {
	        AddHost('Name' => 'AAA');
	        AddHost('Name' => $LocalComponent);
	        AddLogEntry(
		    'Time' => $Time, 
		    'Type' => 'direct/response', 
		    'FromIP' => 'AAA', 
		    'ToIP' => $LocalComponent, 
		    'Text' => /AAA request accepted/ ? 'Auth request accepted' : 'Auth request rejected');
	    }
	    $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    
	    my $AAARequestType = 'Authorization request';
		my $AAARequestOrigin = undef;
            if (not /ser: AAA request rejected.*:$/) {
	    while (<STDIN>) { # extracting AAA request/reply message
	        s/^\t?([^\t\r]*)\r?$/$1/; # cut trailing '\r'
	        
		if (/^Acct-Status-Type.*= 'Stop \(2\)'$/) {
		    $AAARequestType = 'stop';
		}

		if (/^Acct-Status-Type.*= 'Stop'$/) {
		    $AAARequestType = 'stop';
		}

		if (/^Acct-Status-Type.*= 'Start \(2\)'$/) {
			$AAARequestType = 'start';
		}

		if (/^Acct-Status-Type.*= 'Start'$/) {
			$AAARequestType = 'start';
		}

		if (/^h323-call-origin.*= 'originate'$/) {
			$AAARequestOrigin = 'orig';
		}

		if (/^h323-call-origin.*= 'answer'$/) {
			$AAARequestOrigin = 'answ';
		}
		
		if (!defined $H323_Conf_ID and /^h323-conf-id += 'h323-conf-id=(.*)'$/) {
		    $H323_Conf_ID = $1;
		}

		if (!defined $H323_Conf_ID and /^h323-conf-id += '(.*)'$/) {
		    $H323_Conf_ID = $1;
		}

          	if (/^$/) {
		    $Message .= "\n";
		    last;
		} else {
		    $Message .= "$Tab".$_;
		}
	    }
	    }
	    if ($AAARequestType ne 'Authorization request') {
	        $LogEntry[$#LogEntry]{'Text'} = "Accounting (${AAARequestType}/${AAARequestOrigin})";
	    } elsif (!defined $LogEntry[$#LogEntry]{'Text'}) {
	        $LogEntry[$#LogEntry]{'Text'} = 'Authorization request';
	    }
	} else {
	    # check for special undirect messages
	    
	    if (/\/(b2bua: outgoing session timeout, terminating)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(ser(?:\[[0-9]+\])?: AAA request rejected, processing response:)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'ser');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: outgoing session failed with code .*)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: no route to destination)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: no answer timeout expired, cancelling outgoing session)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: create new call leg with id .* for incoming with id .*)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: redirecting incoming session to .*)$/) {
	        my $Text = String2JS($1);
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: placing outgoing session to .*)$/) {
	        my $Text = String2JS($1);
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(b2bua: outgoing session (started|ended successfuly))$/) {
	        my $Text = String2JS($1);
	        AddHost('Name' => 'b2bua');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(ser(?:\[[0-9]+\])?: got AAA reject explanation "[^"]*", rewriting URI)$/) { #"
	        my $Text = $1;
	        AddHost('Name' => 'ser');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(ser(?:\[[0-9]+\])?: redirecting session to .*)$/) {
	        my $Text = $1;
	        AddHost('Name' => 'ser');
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(rtpproxy(?:\[[0-9]+\])?: new session on a port [0-9]+ created.*)$/) {
	        my $Text = $1;
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/(rtpproxy(?:\[[0-9]+\])?: session on ports [0-9]+\/[0-9]+ is cleaned up)$/) {
	        my $Text = $1;
	        AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
	        $MessagePrefix = "<a name=\"".$#LogEntry."\">";
	    } elsif (/\/rtpproxy(?:\[[0-9]+\])?: RTP stats: 0 in from callee, 0 in from caller/) {
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => "SUGGESTION: No audio in both directions!");
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		} elsif (/\/rtpproxy(?:\[[0-9]+\])?: RTP stats: 0 in from callee, [0-9]+ in from caller/ or
		         /\/rtpproxy(?:\[[0-9]+\])?: RTP stats: [0-9]+ in from callee, 0 in from caller/) {
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/error', 'Text' => "SUGGESTION: One-way audio detected!");
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		} elsif (/\/(rtpproxy(?:\[[0-9]+\])?: RTP stats: [0-9]+ in from callee, [0-9]+ in from caller)/) {
			my $Text = $1;
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		} elsif (/\/(rtpproxy(?:\[[0-9]+\])?: pre-filling calle[er]'s address with .*)$/) { #'
			my $Text = $1;
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		} elsif (/\/(rtpproxy(?:\[[0-9]+\])?: lookup on a ports .*, session timer restarted)$/) {
			my $Text = $1;
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => $Text);
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		} elsif (/\/(rtpproxy(?:\[[0-9]+\])?: caller's address filled in:.*)$/) { #'
			my $Text = $1;
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => 'SUGGESTION: first media packet from caller for the stream has been received by rtpproxy');
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		} elsif (/\/(rtpproxy(?:\[[0-9]+\])?: callee's address filled in:.*)$/) { #'
			my $Text = $1;
			AddLogEntry('Time' => $Time, 'Type' => 'undirect/common', 'Text' => 'SUGGESTION: first media packet from callee for the stream has been received by rtpproxy');
			$MessagePrefix = "<a name=\"".$#LogEntry."\">";
		}
	}
       
        if (defined $Mode_html) {
           print "log.document.write('$MessagePrefix".String2JS($Message)."');\n";
        }
    # is there following message has been sent/received
    } elsif (/^([^ ]+ [^ ]+) ([0-9][0-9]:[0-9][0-9]:[0-9][0-9])\/GLOBAL\/([^:[]+)(?:\[[0-9]+\])?: (SENT message to|SENDING message to|RECEIVED message from) ([.0-9]+):([0-9]+):$/) {
        my $Time = $2;
	my $LocalComponent = $3;
	my $RemoteIP = $5;
	my $RemotePort = $6;
	my $RemoteComponent = ($RemoteIP eq $PortaSIP_IP and $RemotePort eq '5060')?'ser':(($RemoteIP eq $PortaSIP_IP and $RemotePort eq '5061')?'b2bua':(($RemoteIP eq $PortaSIP_IP and $RemotePort eq '5062')?'asterisk':''));
	
	if (!defined $Date) {
	    $Date = $1;
	}

        my $Message = ''; # temporary buffer for the message
        my $Call_ID_was_found = 0;
        my $Content_Length = 0;
	my $CSeq;
	my $MsgCallID;
	my $ShortCSeq;
	my $From;
	my $FromTag;
	my $To;
	my $ToTag;
	my $CurrentDialogID;
	my $WarningFlag;
	my $SDPFlag;

        $Message .= "log.document.write('".String2JS($_)."');\n";
	
	my $FromHostName;
	my $FromHostDescription;
	my $ToHostName;
	my $DupMessage = 0;
	if (/: SENDING message to|: SENT message to/) {
	    $FromHostName = $LocalComponent;
	    $ToHostName = $RemoteComponent?$RemoteComponent:$RemoteIP;
	    if ($FromHostName eq 'ser' and $ToHostName eq 'b2bua' or $FromHostName eq 'b2bua' and $ToHostName eq 'ser' or $FromHostName eq $ToHostName) {$DupMessage = 1;}
	} else {
	    $FromHostName = $RemoteComponent?$RemoteComponent:$RemoteIP;
	    $ToHostName = $LocalComponent;
	}

        my $IsFirstLine = 1;
	my $Text;
        while (<STDIN>) { # extracting a message
	    s/^\t?([^\t\r]*)\r?$/$1/; # cut trailing '\r'
	    
	    if ($IsFirstLine) {
	        /([^\n]+)/;
	        $Text = $1;
		$IsFirstLine = 0;
	    }
	    
            if (/^Call-ID: *($Call_ID)$/) { # is the message with our Call-ID?
		$MsgCallID = $1;
                $Call_ID_was_found = 1;
	
            } elsif (/^CSeq: *([0-9]+) +([a-z])([a-z]*)/i) { # get CSeq of the message
	        $CSeq = $1.' '.$2.$3 if (defined $1 and defined $2);
	        $ShortCSeq = (defined $1 and defined $2) ? ($1.'/'.$2) : '?';

#            } elsif (/^From: *([^\r\n]+)(\;tag=([^ \r\n]+))?$/i) {
            } elsif (/^From: */i) {
                if (/\;tag=/) {
		    /^From: *([^\r\n]+)\;tag=([^ \r\n]+)$/i;
	            $From = $1;
		    $FromTag = $2;
		} else {
		    /^From: *([^\r\n]+)$/i;
	            $From = $1;
		}
#            } elsif (/^To: *([^\r\n]+)(\;tag=([^ \r\n]+))?$/i) {
            } elsif (/^To: */i) {
                if (/\;tag=/) {
		    /^To: *([^\r\n]+)\;tag=([^ \r\n]+)$/i;
	            $To = $1;
		    $ToTag = $2;
		} else {
		    /^To: *([^\r\n]+)$/i;
	            $To = $1;
		}

            } elsif (/^Content-Length: *([0-9]+)$/) { # is there following message content
	        $Content_Length = $1;

            } elsif (/^(User-Agent|Server): *(.+)$/) {
	        $FromHostDescription = $2;

            } elsif (/^Warning: *(.+)$/) {
	        $WarningFlag = 1;

            } elsif (/^Content-Type: *application\/sdp$/) {
	        $SDPFlag = 1;

	    } elsif (/^$/) {
                if ($Content_Length > 0) {

                    $Message .= "log.document.write('$Tab\\n');\n";

                    while (<STDIN>) { # extracting the message content
	                s/^\t?([^\t\r]*)\r?$/$1/; # cut trailing '\r'
			
			last if (/^$/);

                        $Message .= "log.document.write('$Tab".String2JS($_)."');\n";
		    }
		}
	        last;
	    }

            $Message .= "log.document.write('$Tab".String2JS($_)."');\n";
        }

	if ($Call_ID_was_found) {
#	    print '1{'.$From.'}  2{'.$To.'}  3{'.$ToTag."}\n\n";
	    if (!$DupMessage) {
	        AddHost('Name' => $FromHostName, 'Description' => $FromHostDescription);
	        AddHost('Name' => $ToHostName); # ???!!!
	        if ($FromHostName eq $ToHostName) {
		    AddLogEntry(
	                'Time' => $Time, 
		        'Type' => 'undirect/error', 
		        'Text' => "WARNING: \"$FromHostName\" has sent a message to itself!");
		} elsif ($Text =~ /^SIP\/[0-9]+\.[0-9]+ (.*)/) {
	            $CurrentDialogID = GetDialogID('CallID' => (defined $MsgCallID?$MsgCallID:''), 'FromTag' => (defined $FromTag?$FromTag:''), 'ToTag' => (defined $ToTag?$ToTag:''));
		    AddLogEntry(
	                'Time' => $Time,
		        'Type' => 'direct/response',
		        'FromIP' => $FromHostName,
		        'ToIP' => $ToHostName,
			'CallID' => $MsgCallID,
			'CSeq' => $CSeq,
		        'From' => $From,
		        'To' => $To,
		        'FromTag' => $FromTag,
		        'ToTag' => $ToTag,
		        'WarningFlag' => $WarningFlag,
		        'SDPFlag' => $SDPFlag,
			'DialogID' => $CurrentDialogID,
		        'Text' => "(${CurrentDialogID} ${ShortCSeq}) ".$1);
		} else {
		    $Text =~ /^([^ ]+) /;
	            $CurrentDialogID = GetDialogID('CallID' => (defined $MsgCallID?$MsgCallID:''), 'FromTag' => (defined $FromTag?$FromTag:''), 'ToTag' => (defined $ToTag?$ToTag:''));
	            AddLogEntry(
	                'Time' => $Time, 
		        'Type' => 'direct/request', 
		        'FromIP' => $FromHostName, 
		        'ToIP' => $ToHostName,
			'CallID' => $MsgCallID,
			'CSeq' => $CSeq,
		        'From' => $From,
		        'To' => $To,
		        'FromTag' => $FromTag,
		        'ToTag' => $ToTag,
		        'WarningFlag' => $WarningFlag,
		        'SDPFlag' => $SDPFlag,
			'DialogID' => $CurrentDialogID,
		        'Text' => "(${CurrentDialogID} ${ShortCSeq}) ".$1);
		}

	        if (defined $Mode_html) {
                    print "log.document.write('<a name=\"".$#LogEntry."\">');\n";
		}
	    }
	    
	    if (defined $Mode_html) {
                print $Message;
	        print "log.document.write('\\n');\n";
	    }
	}
    }
}

CompleteDialogs() if (!defined $NoDialogID);

$H323_Conf_ID = defined $H323_Conf_ID ? $H323_Conf_ID : 'not found';

if (defined $Mode_html) {
    print <<EOF;

log.document.write('</pre></body></html>');
log.document.close();
// end of bottom (log) frame
//-----------------------------------------------------------
// start of top (diagram) frame
diagram.document.open();

diagram.document.write('<html>\\n');
diagram.document.write('<style type=text/css><!--\\n');
diagram.document.write('    body {\\n');
diagram.document.write('      margin:  3px;}\\n');
diagram.document.write('    a, a:visited {\\n');
diagram.document.write('      text-decoration: none;}\\n');
diagram.document.write('    a:hover, a:visited:hover {\\n');
diagram.document.write('      text-decoration: bold;}\\n');
diagram.document.write('    pre.diagram {\\n');
diagram.document.write('      font-family: monospace;\\n');
diagram.document.write('      font-size:   11px;\\n');
diagram.document.write('      line-height: 1;\\n');	        
diagram.document.write('      letter-spacing: -1;}\\n');
diagram.document.write('    .background1 {\\n');
diagram.document.write('      background-color: silver;}\\n');
diagram.document.write('    .background2 {\\n');
diagram.document.write('      background-color: #e0e0e0;}\\n');
diagram.document.write('    .request     {color: black;}\\n');
diagram.document.write('    .ACK_request {color: gray;}\\n');
diagram.document.write('    .auth_accepted {color: green;}\\n');
diagram.document.write('    .auth_rejected {color: red;}\\n');
diagram.document.write('    .code_1xx    {color: gray;}\\n');
diagram.document.write('    .code_2xx    {color: green;}\\n');
diagram.document.write('    .code_3xx    {color: brown;}\\n');
diagram.document.write('    .code_4xx    {color: red;}\\n');
diagram.document.write('    .code_5xx    {color: red;}\\n');
diagram.document.write('    .error       {color: red;\\n');
diagram.document.write('      background-color: #ffeaea;}\\n');
diagram.document.write('    .common      {color: black;\\n');
diagram.document.write('      background-color: #eaeaea;}\\n');
diagram.document.write('/--></style>\\n');

diagram.document.write('<body>\\n<pre> siplogview version: $_Version\\n\\n PortaSIP node: $PortaSIP_IP\\n Call-ID:       $Call_ID\\n H323-Conf-ID:  $H323_Conf_ID</pre>\\n<table border="0" cellspacing="1" cellpadding="2" bgcolor="black"><tr><td bgcolor="white"><table border="0" cellspacing="0" cellpadding="0"><tr><td><pre class="diagram">');

EOF
    if ($#LogEntry < 0) {
        print <<EOF;
diagram.document.write('No messages found for the Call-ID in the log file.\\n');
diagram.document.write('</pre></td></tr></table></td></tr></table></body></html>\\n');

diagram.document.close();
// end of top (diagram) frame
}
</script>

<frameset rows="60%,*" onLoad="fill_frames();">
    <frame name="diagram" src="/images/spacer.gif">
    <frame name="log" src="/images/spacer.gif">
</frameset>

</html>
EOF
        exit;
    }
} else {
    print " siplogview version: $_Version\n\n PortaSIP node: $PortaSIP_IP\n Call-ID:       $Call_ID\n H323-Conf-ID:  $H323_Conf_ID\n\n";

    if ($#LogEntry < 0) {
        print "No messages found for the Call-ID in the log file.";
        exit;
    }
}

#------------- DIAGRAM -------------
PrintDiagramHeader();

if (defined $Mode_html) {
    print "diagram.document.write(' ".sprintf("%-7.7s", $Date)." ";
    foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
        printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', '|');
    }
    print "\\n');\n";
} else {
    print " ".sprintf("%-7.7s", $Date)." ";
    foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
        printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', '|');
    }
    print "\n";
}

for (my $LogIndex = 0; $LogIndex <= $#LogEntry; $LogIndex++) {
    my $Class;
    
    if (defined $Mode_html) {
        print "diagram.document.write('$LogEntry[$LogIndex]{'Time'} ";
    } else {
        print "$LogEntry[$LogIndex]{'Time'} ";
    }

    if ($LogEntry[$LogIndex]{'Type'} =~ /^direct\/.*/) {
        if (defined $Mode_html) {
            if ($LogEntry[$LogIndex]{'Text'} =~ /^(\([^)]+\) )?([0-9]+)/) {
	        my $ResponseCode = $2;
                if ($ResponseCode =~ /1[0-9][0-9]/) {
	            $Class = 'code_1xx';
	        } elsif ($ResponseCode =~ /2[0-9][0-9]/) {
	            $Class = 'code_2xx';
	        } elsif ($ResponseCode =~ /3[0-9][0-9]/) {
	            $Class = 'code_3xx';
	        } elsif ($ResponseCode =~ /4[0-9][0-9]/) {
	            $Class = 'code_4xx';
	        } else {
	            $Class = 'code_5xx';
	        }
	    } elsif ($LogEntry[$LogIndex]{'Text'} =~ /^(\([^)]+\) )?ACK([^a-z]|$)/i) {
	        $Class = 'ACK_request';
	    } elsif ($LogEntry[$LogIndex]{'Text'} =~ /^Auth request accepted$/i) {
	        $Class = 'auth_accepted';
		} elsif ($LogEntry[$LogIndex]{'Text'} =~ /^Auth request rejected$/i) {
			$Class = 'auth_rejected';
	    } else {
	        $Class = 'request';
	    }
        }

        my $FromHostID =  $Host{$LogEntry[$LogIndex]{'FromIP'}}{'Order'};
        my $ToHostID =    $Host{$LogEntry[$LogIndex]{'ToIP'}}{'Order'};
	my $StartHostID = $FromHostID < $ToHostID ? $FromHostID : $ToHostID;
	my $EndHostID =   $FromHostID > $ToHostID ? $FromHostID : $ToHostID;

        for (my $i = 0; $i < $StartHostID; $i++) {
            printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', '|');
        }

        print ' '.($StartHostID == $FromHostID ? '@->' : '|<-');

        my $i = ($FieldWidth +1) *($EndHostID-$StartHostID) -7;


	$LogEntry[$LogIndex]{'WarningFlag'} = $LogEntry[$LogIndex]{'WarningFlag'} ne '' ? '!' : '';
	$LogEntry[$LogIndex]{'SDPFlag'} = $LogEntry[$LogIndex]{'SDPFlag'} ne '' ? '$' : '';
	    
        if ($LogEntry[$LogIndex]{'CSeq'} ne '' and ($LogEntry[$LogIndex]{'WarningFlag'} ne ''  or $LogEntry[$LogIndex]{'SDPFlag'} ne '')) {
          $LogEntry[$LogIndex]{'Text'} =~ s/^(\([^)]*\)) (.*)$/$1 $LogEntry[$LogIndex]{'WarningFlag'}$LogEntry[$LogIndex]{'SDPFlag'} $2/;
        }

        my $s = sprintf('%-.'.$i.'s', $LogEntry[$LogIndex]{'Text'});
		if (defined $Mode_html) {
	        $s =~ s/'/\\'/g;
		}
	my $j = length($s);
	
        if (defined $Mode_html) {
            $s =~ s/(\([^)]*\) !?)\$(.*)$/$1&#9834$2/ if ($LogEntry[$LogIndex]{'SDPFlag'} ne '');
            print ' <span class="'.$Class.'" style="cursor: pointer;" onClick="parent.moveToPacket('.$LogIndex.');" onMouseOver="parent.updateStatus('.$LogIndex.', 1);" onMouseOut="parent.updateStatus('.$LogIndex.', 0);">'.$s.'</span> ';
	} else {
            print ' '.$s.' ';	    
	}
	
	for (my $k = 0; $k < $i-$j; $k++) {
	    print '-';
	}

        print $StartHostID == $ToHostID ? '--@' : '->|';
        printf ('%-'.($FieldWidth-1).'.'.($FieldWidth-1).'s', '');

        my @Keys = keys %Host;
        for (my $i = $EndHostID +1; $i <= $#Keys; $i++) {
            printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', '|');
        }
    } else {
        if ($LogEntry[$LogIndex]{'Type'} eq 'undirect/error') {
	    $Class = 'error';
	} else {
	    $Class = 'common';
	}

        my @Keys = keys %Host;
        my $i = ($FieldWidth +1) *($#Keys +1) -3;
	if (defined $Mode_html) {
	    $LogEntry[$LogIndex]{'Text'} =~ s/'/\\'/g;
            printf '<span class="'.$Class.'">   <span class="'.$Class.'" style="cursor: pointer;" onClick="parent.moveToPacket('.$LogIndex.');" onMouseOver="parent.updateStatus('.$LogIndex.', 1);" onMouseOut="parent.updateStatus('.$LogIndex.', 0);">%-'.($i+4).'.'.($i+4).'s</span>', $LogEntry[$LogIndex]{'Text'}.'</span>';
	} else {
	    printf '   %-'.($i+4).'.'.($i+4).'s', $LogEntry[$LogIndex]{'Text'};
	}
    }

    if (defined $Mode_html) {
        print "\\n');\n";
    } else {
        print "\n";
    }
}

if (defined $Mode_html) {
    print "diagram.document.write(' ".sprintf("%-7.7s", $Date)." ";
    foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
        printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', '|');
    }
    print "\\n');\n";
} else {
    print " ".sprintf("%-7.7s", $Date)." ";
    foreach my $CurrentHost (sort {$Host{$a}{'Order'} <=> $Host{$b}{'Order'}} keys %Host) {
        printf (' %-'.$FieldWidth.'.'.$FieldWidth.'s', '|');
    }
    print "\n";
}

PrintDiagramHeader();

if (defined $Mode_html) {
    print <<EOF;

diagram.document.write('</pre></td></tr></table></td></tr></table></body></html>\\n');

diagram.document.close();
// end of top (diagram) frame
}
</script>

<frameset rows="60%,*" onLoad="fill_frames();">
    <frame name="diagram" src="/images/spacer.gif">
    <frame name="log" src="/images/spacer.gif">
</frameset>

</html>
EOF
}
}
#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------

sub Parse_Params {
    GetOptions ('h|help' =>	\$Option_help,
                'log' =>	\$Mode_log,
                'diagram' =>	\$Mode_diagram,
#                'mixed' =>	\$Mode_mixed,
                'html' =>	\$Mode_html,

#                'c|no-content' =>	\$NoContent,
#                'i|no-Dialogs' =>	\$NoDialogID,
#                'h|no-header' =>	\$NoHeader,
                's=s' =>	\$TZ_shift,
                'z=s' =>	\$TZ_name,
                'p=i' =>	\$i_env,
                'r=s' =>	\$AAA_ip,
		
	        't|no-tabs' =>		\$NoTabs,
#                'v' =>			\$MoreInfo,
   	        'w=i' =>		\$FieldWidth,

       	        'a=s' =>	\$PortaSIP_IP,
	        'l=i' =>	\$MessageLinesLimit,
                'm=i' =>	\$MessagesLimit,
#                'u=i' =>	\$UAsLimit,
               );
		
$Call_ID = $ARGV[0];

if ($Option_help) {
    print $_HelpScreen;
    exit;	
}

$Mode_log = 1 if (!(defined $Mode_log || defined $Mode_diagram || defined $Mode_html));

die "Only one of '--log', '--diagram' and '--html' options should be specified.\nType 'siplogview.pl --help' to view the command options and usage.\n" 
  if (defined $Mode_log && defined $Mode_diagram ||
      defined $Mode_diagram && defined $Mode_html ||
      defined $Mode_html && defined $Mode_log);

die "Call-ID should be specified.\nType 'siplogview.pl --help' to view the command options and usage.\n"
  if (!defined $Call_ID);

die "PortaSIP IP-address should be specified ('-a' option).\nType 'siplogview.pl --help' to view the command options and usage.\n"
  if (!defined $PortaSIP_IP && (defined $Mode_diagram || defined $Mode_html));

die "'-w' value is too small. It should be >= 7.\nType 'siplogview.pl --help' to view the command options and usage.\n"
  if (defined $FieldWidth && $FieldWidth < 7);

$Tab = defined $NoTabs ? '' : "\t";

}

#----------------------------------------------------------------------------------------
# main();

Parse_Params;

if (defined $Mode_log) {
    # proceed with '--log' option
    Without_Diagram();
} else {
    # proceed with '--diagram' or '--html' option
    With_Diagram();
}

exit(0);

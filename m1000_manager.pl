#!/usr/bin/perl
#
#  Oberheim Matrix-1000 Manager version 0.1
#
#  Copyright (C) 2014 LinuxTECH.NET
#
#  Oberheim is a registered trademark of Gibson Guitar Corp.
#
#  This program is free software: you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  version 2 as published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#  See the GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

my $version="0.1";

use Tk;
use Tk::Pane;
use Tk::NoteBook;
use Tk::BrowseEntry;
use Tk::Optionmenu;
use Tk::JPEG;
use Tk::PNG;
use Time::HiRes qw(usleep);

# check if OS is Linux or Windows for OS specific sections
my $LINUX;
my $WINDOWS;
BEGIN{ if ($^O eq 'linux') { $LINUX=1; } elsif ($^O eq 'MSWin32') {$WINDOWS=1;} }

use if ($LINUX), 'MIDI::ALSA' => ('SND_SEQ_EVENT_PORT_UNSUBSCRIBED',
                                  'SND_SEQ_EVENT_SYSEX');

use if ($WINDOWS), 'Win32API::MIDI';

# initialise MIDI on Linux and Windows
my $midi;
my $midiIn;
my $midiOut;
if ($LINUX) {
    MIDI::ALSA::client("M1000 Manager PID_$$",1,1,1);
    MIDI::ALSA::start();
} elsif ($WINDOWS) {
    $midi = new Win32API::MIDI;
}

# default M1000 device number (1-16)
my $dev_nr=1;

### Global Defaults

# LCD style background colour
my $LCDbg='#E5FFB1'; #'#ECFFAF';
# general background colour
my $bgcolor='#DCBE37';
# button colour
my $btncol='#DCDCDC';
# title strips background and font colour
my $Titlebg='#487890';
my $Titlefg='#F3F3F3';

#$Tk::strictMotif=1;

## Global variables
my $modified=0;
my $filename='';
my @PData;

my %Scale_defaults=(
    -width        => 8,
    -length       => 180,
    -sliderlength => 16,
    -borderwidth  => 1,
    -background   => $bgcolor,
    -troughcolor  => 'darkgrey',
    -highlightthickness => 0,
    -showvalue    => 0,
    -font         => "Sans 6",
    -cursor       => 'hand2',
    -orient       => 'horizontal'
);
my %Scale_label_defaults=(
    -width        => 3,
    -height       => 1,
    -borderwidth  => 1,
    -font         => 'Sans 10',
    -foreground   => 'black',
    -background   => $LCDbg,
    -relief       => 'sunken'
);
my %Label_defaults=(
    -font                => 'Sans 8',
    -background          => $bgcolor
);
my %Chkbtn_defaults=(
    -background          => $bgcolor,
    -activebackground    => $bgcolor,
    -highlightthickness  => 0,
    -selectcolor         => $LCDbg,
    -font                => 'Sans 8'
);
my %Frame_defaults=(
    -borderwidth         => 2,
    -highlightthickness  => 0,
    -background          => $bgcolor,
    -relief              => 'groove'
);
my %Default_FrBGCol=(
    -background          => $bgcolor
);
my %BEntry_defaults=(
    -state               => 'readonly',
    -font                => 'Sans 8',
    -style               => 'MSWin32',
);
my %choices_defaults=(
    -borderwidth  => 1,
    -relief       => 'raised',
    -padx         => 1,
    -pady         => 1
);
my %arrow_defaults=(
    -width        => 13,
    -height       => 12,
    -bitmap       => 'darrow'
);
my %Entry_defaults=(
    -borderwidth        => 1,
    -foreground         => 'black',
    -background         => $LCDbg,
    -highlightthickness => 0,
    -insertofftime      => 0,
    -insertwidth        => 1,
    -selectborderwidth  => 0
);
my %TitleLbl_defaults=(
    -font         => 'title',
    -foreground   => $Titlefg,
    -background   => $Titlebg
);
my %RadioB_defaults=(
    -font                => 'Sans 8',
    -indicatoron         => 0,
    -borderwidth         => 1,
    -background          => $btncol,
    -selectcolor         => $LCDbg,
    -highlightthickness  => 1,
    -highlightbackground => $bgcolor,
    -activebackground    => $LCDbg
);

# down arrow bitmap for pulldown menu
my $darrow_bits=pack("b11"x10,
    "...........",
    ".111111111.",
    "...........",
    "...........",
    ".111111111.",
    "..1111111..",
    "...11111...",
    "....111....",
    ".....1.....",
    "...........");

# array mapping MIDI note numbers 0-127 to note names C-1 to G9
my @notes;
my @keys=('C ', 'C#', 'D ', 'D#', 'E ', 'F ', 'F#', 'G ', 'G#', 'A ', 'A#', 'B ');
for (my $nnr=0; $nnr<128; $nnr++) {
    my $key=($nnr%12);
    my $oct=int($nnr/12)-1;
    $notes[$nnr]=$keys[$key].$oct;
}
# hash mapping note names C-1 to G9 to MIDI note numbers 0-127
my %noteshash; @noteshash{@notes}=0..$#notes;

# Matrix Modulation Sources

my @mod_sources=('00: Unused', '01: Envelope 1', '02: Envelope 2', '03: Envelope 3', '04: LFO 1', '05: LFO 2',
'06: Vibrato', '07: Ramp 1', '08: Ramp 2', '09: Keyboard', '10: Portamento', '11: Tracking Gen.',
'12: Keyboard Gate', '13: Velocity', '14: Release Vel.', '15: Aftertouch', '16: Pedal 1', '17: Pedal 2',
'18: Lever 1', '19: Lever 2', '20: Lever 3');

# selected and available midi in/out devices
my $midi_outdev="";
my $midi_outdev_prev="";
my $midi_indev="";
my $midi_indev_prev="";
my @midi_indevs=MidiPortList('in');
my @midi_outdevs=MidiPortList('out');

# these widgets need to be global
my $midiin;
my $midiout;
my $midiupload;
my $midi_settings;

my @DCO_frame;
my $VCF_frame;
my $VCA_frame;
my $FM_frame;
my $TrGen_frame;
my @Ramp_frame;
my $Porta_frame;
my @Env_frame;
my @LFO_frame;
my $Keybmode_frame;

# set up main program window
my $mw=MainWindow->new();
$mw->title("M1000 Manager - Oberheim Matrix-1000 Editor");
$mw->resizable(0,0);

$mw->fontCreate('title', -family=>'Sans', -weight=>'bold', -size=>9);

$mw->DefineBitmap('darrow'=>11,10,$darrow_bits);

# default font
$mw->optionAdd('*font', 'Sans 10');

# for better looking menus
$mw->optionAdd('*Menu.activeBorderWidth', 1, 99);
$mw->optionAdd('*Menu.borderWidth', 1, 99);
$mw->optionAdd('*Menubutton.borderWidth', 1, 99);
$mw->optionAdd('*Optionmenu.borderWidth', 1, 99);
# set default listbox properties
$mw->optionAdd('*Listbox.borderWidth', 3, 99);
$mw->optionAdd('*Listbox.selectBorderWidth', 0, 99);
$mw->optionAdd('*Listbox.highlightThickness', 0, 99);
$mw->optionAdd('*Listbox.Relief', 'flat', 99);
$mw->optionAdd('*Listbox.Width', 0, 99);
$mw->optionAdd('*Listbox.Height', 10, 99);
# set default entry properties
$mw->optionAdd('*Entry.borderWidth', 1, 99);
$mw->optionAdd('*Entry.highlightThickness', 0, 99);
$mw->optionAdd('*Entry.disabledForeground','black',99);
$mw->optionAdd('*Entry.disabledBackground', $LCDbg,99);
# set default scrollbar properties
$mw->optionAdd('*Scrollbar.borderWidth', 1, 99);
$mw->optionAdd('*Scrollbar.highlightThickness', 0, 99);
$mw->optionAdd('*Scrollbar.Width', 10, 99);
# set default button properties
$mw->optionAdd('*Button.borderWidth', 1, 99);
$mw->optionAdd('*Button.highlightThickness', 0, 99);
$mw->optionAdd('*Checkbutton.borderWidth', 1, 99);
# set default canvas properties
$mw->optionAdd('*Canvas.highlightThickness', 0, 99);

# create main window layout
my $Col_0  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_1  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_2  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
#my $Col_34 =$mw->Frame()->pack(-side=>'top',    -fill=>'y');
my $Col_34b=$mw->Frame()->pack(-side=>'bottom', -fill=>'x');
my $Col_3  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_4  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');

$midi_settings=$Col_34b->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);

$Env_frame[0]=$Col_2->Frame(%Frame_defaults)->pack(-side=>'top');
Env_Frame(0);
$Env_frame[1]=$Col_3->Frame(%Frame_defaults)->pack(-side=>'top');
Env_Frame(1);
$Env_frame[2]=$Col_4->Frame(%Frame_defaults)->pack(-side=>'top');
Env_Frame(2);

$DCO_frame[0]=$Col_0->Frame(%Frame_defaults)->pack(-side=>'top');
DCO_Frame(0);
$LFO_frame[0]=$Col_0->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'y', -expand=>1);
LFO_Frame(0);

$DCO_frame[1]=$Col_1->Frame(%Frame_defaults)->pack(-side=>'top');
DCO_Frame(1);
$LFO_frame[1]=$Col_1->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'y', -expand=>1);
LFO_Frame(1);

$VCA_frame=$Col_3->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
VCA_Frame();
$Porta_frame=$Col_3->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
Porta_Frame();

$Ramp_frame[0]=$Col_0->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'y', -expand=>1);
Ramp_Frame(0);
$Ramp_frame[1]=$Col_1->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'y', -expand=>1);
Ramp_Frame(1);

$VCF_frame=$Col_2->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
VCF_Frame();
$FM_frame=$Col_2->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
FM_Frame();

$TrGen_frame=$Col_4->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>1);
TrGen_Frame();
$Keybmode_frame=$Col_4->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>1);
Keybmode_Frame();

MIDI_IOconfig();

MainLoop;


# -----------
# Subroutines
# -----------

# create an array of available midi ports
sub MidiPortList {
    my($dir)=@_;
    my @portlist;

    if ($LINUX) {
        my %clients = MIDI::ALSA::listclients();
        my %portnrs = MIDI::ALSA::listnumports();
        my $tmp=0;
        while (my ($key, $value) = each(%clients)){
            if ($key>15 && $key<128) {
                for (my $i=0; $i<($portnrs{$key}); $i++) {
                    $portlist[$tmp]=$value.":".$i;
                    $tmp++;
                }
            }
        }
    }
    elsif ($WINDOWS) {
        if ($dir eq 'in') {
            my $iNumDevs=$midi->InGetNumDevs();
            for (my $i=0; $i<$iNumDevs; $i++) {
                my $cap=$midi->InGetDevCaps($i);
                $portlist[$i]=$$cap{szPname};
            }
        } elsif ($dir eq 'out') {
            my $oNumDevs=$midi->OutGetNumDevs();
            for (my $o=0; $o<$oNumDevs; $o++) {
                my $cap=$midi->OutGetDevCaps($o);
                $portlist[$o]=$$cap{szPname};
            }
        }
    }
    return @portlist;
}

# set up a new midi connection and drop the previous one
sub MidiConSetup {
    my($dir)=@_;

    if ($LINUX) {
        MIDI::ALSA::stop();
        if ($dir eq 'out') {
            if ($midi_outdev_prev ne '') {
                MIDI::ALSA::disconnectto(1,"$midi_outdev_prev");
            }
            $midi_outdev_prev=$midi_outdev;
            MIDI::ALSA::connectto(1,"$midi_outdev");
        } elsif ($dir eq 'in') {
            if ($midi_indev_prev ne '') {
                MIDI::ALSA::disconnectfrom(0,"$midi_indev_prev");
            }
            $midi_indev_prev=$midi_indev;
            MIDI::ALSA::connectfrom(0,"$midi_indev");
        }
        MIDI::ALSA::start();
    }
    elsif ($WINDOWS) {
        if ($dir eq 'out') {
            if ($midi_outdev_prev ne '') {
                $midiOut->Close();
            }
            $midi_outdev_prev=$midi_outdev;
            my $dev=$midi->OutGetDevNum($midi_outdev);
            $midiOut=new Win32API::MIDI::Out($dev);
        } elsif ($dir eq 'in') {
            # add Windows specific code here
        }
    }
    if (($midi_indev ne '') && ($midi_outdev ne '')) {
    #    $vcdwn_btn->configure(-state=>'active');
    #   if (Exists($rywin)) { $rykitdwn_btn->configure(-state=>'active'); }
    } else {
    #    $vcdwn_btn->configure(-state=>'disabled');
    #   if (Exists($rywin)) { $rykitdwn_btn->configure(-state=>'disabled'); }
    }
    if ($midi_outdev ne '') {
    #   $midiupload->configure(-state=>'active');
    #   if (Exists($rywin)) { $rymidiupload->configure(-state=>'active'); }
    } else {
    #   $midiupload->configure(-state=>'disabled');
    #   if (Exists($rywin)) { $rymidiupload->configure(-state=>'disabled'); }
    }
}

# Standard Horizontal Slider Subroutine
sub StdSlider {
    my($frame, $var, $from, $to, $intv, $incr, $param, $label, $transf)=@_;
    if (! $transf) {$transf=''}

    my $scale=$$frame->Scale(%Scale_defaults,
        -variable     =>  $var,
        -to           =>  $to,
        -from         =>  $from,
        -resolution   =>  $incr,
        -tickinterval =>  $intv,
        -label        =>  $label,
        -command      => sub{ SendPaChMsg($param,(eval"$$var$transf")); }
    )->grid(
    my $spinbox=$$frame->Spinbox(%Entry_defaults,
        -width        =>  3,
        -justify      => 'center',
        -font         => 'Sans 10',
        -textvariable =>  $var,
        -to           =>  $to,
        -from         =>  $from,
        -increment    =>  $incr,
        -state        => 'readonly',
#          -validate           => 'key',
#          -validatecommand    => sub {($_[0]=~/^[-]?[0-9]{1,3}$/ && $_[0]>=$from && $_[0]<=$to)},
#          -invalidcommand     => sub {},
        -readonlybackground => $LCDbg,
        -command      => sub{ SendPaChMsg($param,(eval"$$var$transf")); }
    ),-padx=>1);
    return ($scale,$spinbox);
}

# Grid Label
sub GridLabel {
    my ($frame,$text)=@_;
    $$frame->Label(-font=>'Sans 8', -text=>$text)->grid(-columnspan=>2);
}

# Radiobuttons with Labels and Title
sub OptSelect {
    my ($frame, $var, $options, $parm, $btnwidth, $desc, $nofr)=@_;
    my $sf;
    my $optnr=(@{$options});

    # create wrapper frame unless $nofr is set
    if (! $nofr) {
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(-columnspan=>2);
    } else {
        $sf=$$frame;
    }
    if ($desc) { 
        $sf->Label(%Label_defaults,
            -text     => $desc
        )->grid(-row=>0, -columnspan=>$optnr);
    }
    for (my $n=0; $n<$optnr; $n++) {
        $sf->Radiobutton(%RadioB_defaults,
            -text     => $$options[$n],
            -width    => $btnwidth,
            -value    => $n,
            -variable => $var,
            -command  => sub{ SendPaChMsg($parm,$$var); }
        )->grid(-row=>1, -column=>$n);
    }
}

# Pulldown Menu with Label
sub PullDwnMenu {
    my ($frame, $var, $options, $parm, $menuwidth, $desc, $nofr)=@_;
    my $sf;

    # create wrapper frame unless $nofr is set
    if (! $nofr) {
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(-columnspan=>2);
    } else {
        $sf=$$frame;
    }
    $sf->Label(%Label_defaults,
        -text         => $desc
    )->grid(
    my $entry=$sf->BrowseEntry(%BEntry_defaults,
        -variable     => $var,
        -choices      => $options,
        -width        => $menuwidth,
        -font         => 'Fixed 8',
        -browsecmd    => sub{ SendPaChMsg($parm,($$var=~/^(\d\d):.*/)); }
    ),-pady=>2);
    $entry->Subwidget("choices")->configure(%choices_defaults);
    $entry->Subwidget("arrow")->configure(%arrow_defaults);
}

# ON/OFF Switch
sub OnOffSwitch {
    my ($frame, $var, $parm, $desc, $nofr)=@_;
    my $sf;

    # create wrapper frame unless $nofr is set
    if (! $nofr) {
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(-columnspan=>2, -pady=>1);
    } else {
        $sf=$$frame;
    }
    $sf->Label(%Label_defaults,
        -text         => $desc
    )->pack(-side=>'left');
    $sf->Checkbutton(%Chkbtn_defaults,
        -pady         => '2',
        -text         => 'on/off',
        -variable     => $var,
        -command      => sub{ SendPaChMsg($parm,$$var); }
    )->pack(-side=>'left');
}

# Standard subframe with header, returns subframe created
sub StdFrame {
    my($frame, $title)=@_;

    $$frame->Label(%TitleLbl_defaults,
        -text=>$title
    )->pack(-fill=>'x', -expand=>1, -anchor=>'n');
    
    my $subframe=$$frame->Frame(%Default_FrBGCol
    )->pack(-fill=>'x', -expand=>1, -anchor=>'n', -padx=>4, -pady=>4);

    return $subframe;
}

# quit the program, ask for confirmation if unsaved changes
sub exitProgam {
    if ($modified == 1) {
        my $rtn=UnsavedChanges('Quit anyway?');
        if ($rtn eq 'Yes') {
            if ($WINDOWS && ($midi_outdev ne '')) { $midiOut->Close(); }
            exit;
        }
    } else {
        if ($WINDOWS && ($midi_outdev ne '')) { $midiOut->Close(); }
        exit;
    }
}

# Play a Note via MIDI (send 'note on' or 'note off' event)
sub PlayMidiNote {
    my $ch=$_[0]; # midi channel 0-15
    my $nt=$_[1]; # midi note 0-127
    my $vl=$_[2]; # note velocity 0-127
    my $oo=$_[3]; # note on (1) or note off (0)
    if ($LINUX) {
        if ($oo) {
            MIDI::ALSA::output(MIDI::ALSA::noteonevent($ch,$nt,$vl));
        } else {
            MIDI::ALSA::output(MIDI::ALSA::noteoffevent($ch,$nt,$vl));
        }
    } elsif ($WINDOWS && ($midi_outdev ne '')) {
        my $msg=($vl*65536)+($nt*256)+(128+$ch+($oo*16));
        $midiOut->ShortMsg($msg);
    }
}

# send Patch Parameter Change Message (real time sysex) to Matrix-1000
sub SendPaChMsg {
    my($param, $value)=@_;

    print STDOUT "par:[$param] val:[$value]\n"; # for debug purposes
    if ($midi_outdev ne '') {
        if ($value < 0){ $value=$value+128; }   # handle negative values correctly
        my $ddata="\x10\x06\x06".chr($param).chr($value);
        usleep ( 20000 );
        if ($LINUX) {
            MIDI::ALSA::output( MIDI::ALSA::sysex( $dev_nr-1, $ddata, 0 ) );
        }
        elsif ($WINDOWS) {
            my $buf="\xF0".$ddata."\xF7";
            my $midihdr = pack ("PLLLLPLL", $buf, length $buf, 0, 0, 0, undef, 0, 0);
            my $lpMidiOutHdr = unpack('L!', pack('P', $midihdr));
            $midiOut->PrepareHeader($lpMidiOutHdr);
            $midiOut->LongMsg($lpMidiOutHdr);
            $midiOut->UnprepareHeader($lpMidiOutHdr);
        }
    }
}


# MIDI input and output devices selection
sub MIDI_IOconfig {
    $midi_settings->Label(%TitleLbl_defaults, -text=> 'MIDI Devices Configuration'
    )->pack(-fill=>'x', -expand=>1, -anchor=>'n');

    my $subframe=$midi_settings->Frame(%Default_FrBGCol,
    )->pack(-fill=>'x', -expand=>1, -pady=>14);

    # MIDI OUT device selection
    $subframe->Label(%Label_defaults,
        -text         => "Output MIDI Device to Matrix-1000: ",
        -font         => 'Sans 9',
        -justify      => 'right'
    )->grid(-row=>0, -column=>0, -sticky=>'e', -pady=>8);

    $midiout=$subframe->BrowseEntry(%BEntry_defaults,
        -variable     => \$midi_outdev,
        -choices      => \@midi_outdevs,
        -font         => 'Sans 9',
        -width        => 28,
        -listheight   => 9,
        -browsecmd    => sub{ MidiConSetup('out'); },
        -listcmd      => sub{ @midi_outdevs=MidiPortList('out');
                              $midiout->delete( 0, "end" );
                              $midiout->insert("end", $_) for (@midi_outdevs); }
    )->grid(-row=>0, -column=>1, -sticky=>'w', -pady=>8);

    $midiout->Subwidget("choices")->configure(%choices_defaults);
    $midiout->Subwidget("arrow")->configure(%arrow_defaults);

    if (!$LINUX && !$WINDOWS) { $midiout->configure(-state=>'disabled'); }

    # MIDI IN device selection
    $subframe->Label(%Label_defaults,
        -text         => "Input MIDI Device from Matrix-1000: ",
        -font         => 'Sans 9',
        -justify      => 'right'
    )->grid(-row=>1, -column=>0, -sticky=>'e', -pady=>8);

    $midiin=$subframe->BrowseEntry(%BEntry_defaults,
        -variable     => \$midi_indev,
        -choices      => \@midi_indevs,
        -font         => 'Sans 9',
        -width        => 28,
        -listheight   => 9,
        -browsecmd    => sub{ MidiConSetup('in'); },
        -listcmd      => sub{ @midi_indevs=MidiPortList('in');
                              $midiin->delete( 0, "end" );
                              $midiin->insert("end", $_) for (@midi_indevs); }
    )->grid(-row=>1, -column=>1, -sticky=>'w', -pady=>8);

    $midiin->Subwidget("choices")->configure(%choices_defaults);
    $midiin->Subwidget("arrow")->configure(%arrow_defaults);

    if (!$LINUX) { $midiin->configure(-state=>'disabled'); }

}

#------------------------------------------------------------------------------------------------
# Editor Frames

sub DCO_Frame {
    my($osc)=@_;
    my $m=($osc*10);
    my $subframe=StdFrame(\$DCO_frame[$osc],'Oscillator (DCO) '.($osc+1));
    my @DCO_wavsel_label;
    if (!$osc) { @DCO_wavsel_label=('off', 'pulse', 'wave', 'both'); }           # DCO 1
    else       { @DCO_wavsel_label=('off', 'pulse', 'wave', 'both', 'noise'); }  # DCO 2
    OptSelect(   \$subframe, \$PData[( 6+$m)],  \@DCO_wavsel_label, (6+$m),  6, 'Oscillator Waveform:');
    OnOffSwitch( \$subframe, \$PData[( 9+$m)],                      (9+$m),     'Key Click: ');
    StdSlider(   \$subframe, \$PData[( 5+$m)],       0,  63,  7, 1, (5+$m),     'Wave Shape (0=saw -> 63=triangle)');
    StdSlider(   \$subframe, \$PData[( 3+$m)],       0,  63,  7, 1, (3+$m),     'Pulse Width (31=square)');
    StdSlider(   \$subframe, \$PData[( 4+$m)],     -63,  63, 14, 1, (4+$m),     'Pulse Width modulation by LFO 2');
    StdSlider(   \$subframe, \$PData[( 0+$m)],       0,  63,  7, 1, (0+$m),     'Frequency (semi-tone increments)');
    StdSlider(   \$subframe, \$PData[( 1+$m)],     -63,  63, 14, 1, (1+$m),     'Frequency modulation by LFO 1');
    if (!$osc) {
     my @DCO1_sync_label=('off', 'soft', 'medium', 'hard');
     OptSelect(  \$subframe, \$PData[  2],      \@DCO1_sync_label,       2,  8, 'DCO Synchronization:');
    } else {
     StdSlider(  \$subframe, \$PData[ 12],         -31,  31,  6, 1,     12,     'Detune DCO 2 relative to DCO 1');
    }
    my @DCO_levers_label=('off', 'p.bend', 'vibrato', 'both');
    OptSelect(   \$subframe, \$PData[( 7+$m)],  \@DCO_levers_label, (7+$m),  8, 'Fixed Modulations:');
    if (!$osc) {
     OnOffSwitch(\$subframe, \$PData[  8],                               8,     'Portamento: '); }
    else {
     my @DCO2_porta_label=('none', 'portam.', 'kb.track');
     OptSelect(  \$subframe, \$PData[ 18],      \@DCO2_porta_label,     18,  8, '');
    }
}

sub VCF_Frame {
    my $subframe=StdFrame(\$VCF_frame,'24dB LP Filter (VCF)');
    StdSlider(   \$subframe, \$PData[ 20],           0,  63,  7, 1,     20,     'Balance (DCO 2 <----|----> DCO 1)');
    StdSlider(   \$subframe, \$PData[ 21],           0, 127, 20, 1,     21,     'Cutoff Frequency');
    StdSlider(   \$subframe, \$PData[ 24],           0,  63,  7, 1,     24,     'Resonance');
    StdSlider(   \$subframe, \$PData[ 22],         -63,  63, 14, 1,     22,     'Frequency modulation by ENV 1');
    StdSlider(   \$subframe, \$PData[ 23],         -63,  63, 14, 1,     23,     'Frequency modulation by Aftertouch');
    my @VCF_levers_label=('off', 'p.bend', 'vibrato', 'both');
    OptSelect(   \$subframe, \$PData[ 25],  \@VCF_levers_label,         25,  8, 'Frequency modulation by:');
    my @VCF_porta_label=('none', 'portam.', 'kb.track');
    OptSelect(   \$subframe, \$PData[ 26],   \@VCF_porta_label,         26,  8, '');
}

sub VCA_Frame {
    my $subframe=StdFrame(\$VCA_frame,'Two-Stage Amplifier (VCA 1 + 2)');
    StdSlider(   \$subframe, \$PData[ 27],           0,  63,  7, 1,     27,     'VCA 1 Volume');
    StdSlider(   \$subframe, \$PData[ 28],         -63,  63, 14, 1,     28,     'VCA 1 modulation by Velocity');
    StdSlider(   \$subframe, \$PData[ 29],         -63,  63, 14, 1,     29,     'VCA 2 modulation by ENV 2');
}

sub FM_Frame {
    my $subframe=StdFrame(\$FM_frame,'FM');
    StdSlider(   \$subframe, \$PData[ 30],           0,  63,  7, 1,     30,     'VCF FM amount');
    StdSlider(   \$subframe, \$PData[ 31],         -63,  63, 14, 1,     31,     'FM modulation by ENV 3');
    StdSlider(   \$subframe, \$PData[ 32],         -63,  63, 14, 1,     32,     'FM modulation by Aftertouch');
}

sub TrGen_Frame {
    my $subframe=StdFrame(\$TrGen_frame,'Tracking Generator');
    PullDwnMenu( \$subframe, \$PData[ 33],      \@mod_sources,          33, 18, 'Tracking source:');
    StdSlider(   \$subframe, \$PData[ 34],           0,  63,  7, 1,     34,     'Tracking Point 1 (0=neutral)');
    StdSlider(   \$subframe, \$PData[ 35],           0,  63,  7, 1,     35,     'Tracking Point 2 (15=neutral)');
    StdSlider(   \$subframe, \$PData[ 36],           0,  63,  7, 1,     36,     'Tracking Point 3 (31=neutral)');
    StdSlider(   \$subframe, \$PData[ 37],           0,  63,  7, 1,     37,     'Tracking Point 4 (47=neutral)');
    StdSlider(   \$subframe, \$PData[ 38],           0,  63,  7, 1,     38,     'Tracking Point 5 (63=neutral)');
}

sub Ramp_Frame {
    my($ramp)=@_;
    my $m=($ramp*2);
    my $subframe=StdFrame(\$Ramp_frame[$ramp],'Ramp Generator '.($ramp+1));
    StdSlider(   \$subframe, \$PData[(40+$m)],       0,  63,  7, 1,(40+$m),     'Rate');
    my @RampTRG_label=('single', 'multi', 'external', 'gated ext');
    OptSelect(   \$subframe, \$PData[(41+$m)],  \@RampTRG_label,   (41+$m),  8, 'Ramp trigger type:');
}

sub Porta_Frame {
    my $subframe=StdFrame(\$Porta_frame,'Portamento');
    StdSlider(   \$subframe, \$PData[ 44],           0,  63,  7, 1,     44,     'Portamento Rate (transition time)');
    StdSlider(   \$subframe, \$PData[ 45],         -63,  63, 14, 1,     45,     'Portamento modulation by Velocity');
    my @Portamode_label=('linear', 'constant', 'exponential');
    OptSelect(   \$subframe, \$PData[ 46],   \@Portamode_label,         46, 10, 'Portamento Mode:');
    OnOffSwitch( \$subframe, \$PData[ 47],                              47,     'Legato Portamento: ');
}

sub Keybmode_Frame {
    my $subframe=StdFrame(\$Keybmode_frame,'Keyboard Mode');
    my @Keybmode_label=('reassign', 'rotate', 'unison', 'reas+rob');
    OptSelect(   \$subframe, \$PData[ 48],   \@Keybmode_label,          48,  8, 'Keyboard Mode:');
}

sub Env_Frame {
    my($env)=@_;
    my $m=($env*10);
    my $subframe=StdFrame(\$Env_frame[$env],'Envelope '.($env+1));
    my @EnvMod_label=('normal', 'DADR', 'freerun', 'both');
    OptSelect(   \$subframe, \$PData[(58+$m)],  \@EnvMod_label,    (58+$m),  7, 'Envelope Mode:');
    StdSlider(   \$subframe, \$PData[(50+$m)],       0,  63,  7, 1,(50+$m),     'Initial Delay Time');
    StdSlider(   \$subframe, \$PData[(51+$m)],       0,  63,  7, 1,(51+$m),     'Attack Time');
    StdSlider(   \$subframe, \$PData[(52+$m)],       0,  63,  7, 1,(52+$m),     'Decay Time');
    StdSlider(   \$subframe, \$PData[(53+$m)],       0,  63,  7, 1,(53+$m),     'Sustain Level');
    StdSlider(   \$subframe, \$PData[(54+$m)],       0,  63,  7, 1,(54+$m),     'Release Time');
    StdSlider(   \$subframe, \$PData[(55+$m)],       0,  63,  7, 1,(55+$m),     'Amplitude Level');
    StdSlider(   \$subframe, \$PData[(56+$m)],     -63,  63, 14, 1,(56+$m),     'Amplitude modulation by Velocity');
    my @TrgMod_label=('KST', 'KSR', 'KMT', 'KMR', 'XST', 'XSR', 'XMT', 'XMR');
    OptSelect(   \$subframe, \$PData[(57+$m)],  \@TrgMod_label,    (57+$m),  4, 'Trigger Mode:');
    my @LFOTrg_label=('off', 'LFO 1', 'G-LFO 1');
    OptSelect(   \$subframe, \$PData[(59+$m)],  \@LFOTrg_label,    (59+$m),  9, 'LFO 1 Trigger:');
}

sub LFO_Frame {
    my($lfo)=@_;
    my $m=($lfo*10);
    my $txt;
    my $subframe=StdFrame(\$LFO_frame[$lfo],'LFO '.($lfo+1));
    my @LFOWav_label=("\x{25B2}", "\x{25E2}", "\x{25E3}", "\x{25FC}", "\x{259F}", "\x{2591}", 'S');
    OptSelect(   \$subframe, \$PData[(82+$m)],  \@LFOWav_label,    (82+$m),  2, 'Waveform:');
    PullDwnMenu( \$subframe, \$PData[(88+$m)],  \@mod_sources,     (88+$m), 18, 'Sample source:');
    StdSlider(   \$subframe, \$PData[(80+$m)],       0,  63,  7, 1,(80+$m),     'Speed');
    if (!$lfo) { $txt='Aftertouch'; } else { $txt='Keyboard'; }
    StdSlider(   \$subframe, \$PData[(81+$m)],     -63,  63, 14, 1,(81+$m),     'Speed modulation by '.$txt);
    StdSlider(   \$subframe, \$PData[(83+$m)],       0,  63,  7, 1,(83+$m),     'Retrigger Point');
    StdSlider(   \$subframe, \$PData[(84+$m)],       0,  63,  7, 1,(84+$m),     'Amplitude');
    StdSlider(   \$subframe, \$PData[(85+$m)],     -63,  63, 14, 1,(85+$m),     'Amplitude modulation by Ramp '.($lfo+1));
    my @TrgMod_label=('off', 'single', 'multi', 'pedal 2');
    OptSelect(   \$subframe, \$PData[(86+$m)],  \@TrgMod_label,    (86+$m),  7, 'Trigger Mode:');
    OnOffSwitch( \$subframe, \$PData[(87+$m)],                     (87+$m),     'Lag: ');

}


#!/usr/bin/perl
#
#  Oberheim Matrix-1000 Manager version 0.5.2
#
#  Copyright (C) 2014-2015 LinuxTECH.NET
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

my $version="0.5.2";
my $year="2014-2015";

use Tk;
use Tk::BrowseEntry;
use Tk::Optionmenu;
use Time::HiRes qw(usleep time);

# check if OS is Linux or Windows for OS specific sections
my $LINUX;
my $WINDOWS;
BEGIN{ if ($^O eq 'linux') { $LINUX=1; } elsif ($^O eq 'MSWin32') { $WINDOWS=1; } }

use if ($LINUX), 'MIDI::ALSA' => ('SND_SEQ_EVENT_PORT_UNSUBSCRIBED',
                                  'SND_SEQ_EVENT_SYSEX');

use if ($WINDOWS), 'Win32API::MIDI';

# slider font size: 6 for Linux, 7 for Windows
my $f1;
if ($LINUX) { $f1="Sans 6"; } elsif ($WINDOWS) { $f1="Tahoma 7"; }

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

# default M1000 MIDI channel number (1-16)
my $dev_nr=1;

### Global Defaults

# LCD style background colour
my $LCDbg='#E5FFB1'; #'#ECFFAF';
# general background colour
my $bgcolor='#DCBE37';
# general font color
my $fontcolor='black';
# button colour
my $btncol='#DCDCDC';
# title strips background and font colour
my $Titlebg='#487890';
my $Titlefg='#F3F3F3';
# slider labels
my $sp=0; # label interval for 0-63 (could be 0,7,9,63)
my $sn=0; # label interval for -63-63 (could be 0,14,63)
my $s3=0; # label interval for -31-31 (could be 0,31)
my $s7=0; # label interval for 0-127 (could be 0,20,127)

#$Tk::strictMotif=1;

## Global variables
my $modified=0;
my $filename='';
my @PData;
my $midilast=0;
my $midilock=0;
my $patnr=0;
my $voice_name='';
my $det_val=0;
my $titlestring="M1000 Manager - Oberheim Matrix-1000 Editor";

my %Scale_defaults=(
    -width        => 10,
    -length       => 180,
    -sliderlength => 20,
    -borderwidth  => 1,
    -background   => $bgcolor,
    -foreground   => $fontcolor,
    -troughcolor  => 'darkgrey',
    -highlightthickness => 0,
    -showvalue    => 0,
    -font         => $f1,
    -cursor       => 'hand2',
    -orient       => 'horizontal'
);
my %Label_defaults=(
    -font                => 'Sans 8',
    -background          => $bgcolor,
    -foreground          => $fontcolor
);
my $selcol;
if ($LINUX) { $selcol=$LCDbg; } elsif ($WINDOWS) { $selcol=$bgcolor; }
my %Chkbtn_defaults=(
    -background          => $bgcolor,
    -foreground          => $fontcolor,
    -activebackground    => $bgcolor,
    -highlightthickness  => 0,
    -indicatoron         => 1,
    -selectcolor         => $selcol,
    -font                => 'Sans 8'
);
my %Default_FrBGCol=(
    -background          => $bgcolor
);
my %Frame_defaults=(%Default_FrBGCol,
    -borderwidth         => 2,
    -highlightthickness  => 0,
    -relief              => 'groove'
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
    -bitmap       => 'bm:darrow'
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
    -highlightthickness  => 0,
    -padx                => 1,
    -pady                => 1,
    -selectcolor         => $LCDbg,
#    -background          => $btncol,
#    -activebackground    => $btncol
);
my %MBar_defaults=(
    -borderwidth => 1,
    -relief      => 'raised'
);

my %GridConf=();

# down arrow bitmap for pulldown menu
my $darrow_bits=pack("b11"x10,
    "...........",    ".111111111.",    "...........",    "...........",    ".111111111.",
    "..1111111..",    "...11111...",    "....111....",    ".....1.....",    "...........");

# triangle wave bitmap
my $triangle_bits=pack("b17"x9,    "....1............",
    "...1.1...........",    "..1...1..........",    ".1.....1.........",    "1.......1.......1",
    ".........1.....1.",    "..........1...1..",    "...........1.1...",    "............1....");

# upsaw wave bitmap
my $upsaw_bits=pack("b17"x9,    "....1.......1....",
    "...11......11....",    "..1.1.....1.1....",    ".1..1....1..1....",    "1...1...1...1...1",
    "....1..1....1..1.",    "....1.1.....1.1..",    "....11......11...",    "....1.......1....");

# downsaw wave bitmap
my $downsaw_bits=pack("b17"x9,    "....1.......1....",
    "....11......11...",    "....1.1.....1.1..",    "....1..1....1..1.",    "1...1...1...1...1",
    ".1..1....1..1....",    "..1.1.....1.1....",    "...11......11....",    "....1.......1....");

# square wave bitmap
my $square_bits=pack("b17"x9,    "1.......111111111",
    "1.......1.......1",    "1.......1.......1",    "1.......1.......1",    "1.......1.......1",
    "1.......1.......1",    "1.......1.......1",    "1.......1.......1",    "111111111.......1");

# random wave bitmap
my $random_bits=pack("b17"x9,    ".....111.........",
    ".....1.1.......11",    ".....1.1..111..1.",    ".....1.1..1.1..1.",    ".111.1.1..1.1..1.",
    ".1.111.1..1.1..1.",    "11.....1..1.1..1.",    ".......1111.1..1.",    "............1111.");

# noise wave bitmap
my $noise_bits=pack("b17"x9,    "......1..........",
    ".....11....1....1",    ".....1.1...1....1",    "..1..1.1..1.1..1.",    ".1.1.1.1..1.1..1.",
    ".1.1.1.1.1..1..1.",    "1...1..1.1...1.1.",    "....1...1....11..",    "..............1..");

# sampled wave bitmap
my $sampled_bits=pack("b17"x9,    "......1111.......",
    ".....11..11......",    "....11...........",    ".....11..........",    "......1111.......",
    ".........11......",    "..........11.....",    ".....11..11......",    "......1111.......");


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
my @mod_sources=('00: Unused',
'01: Envelope 1', '02: Envelope 2', '03: Envelope 3', '04: LFO 1', '05: LFO 2', '06: Vibrato',
'07: Ramp 1', '08: Ramp 2', '09: Keyboard', '10: Portamento', '11: Tracking Gen.', '12: Keyboard Gate',
'13: Velocity', '14: Release Vel.', '15: Aftertouch', '16: Pedal 1', '17: Pedal 2', '18: Lever 1',
'19: Lever 2', '20: Lever 3');

# Matrix Modulation Destinations
my @mod_dest=('00: Unused',
'01: DCO1 Frequency', '02: DCO1 Pulse Width', '03: DCO1 Waveshape',
'04: DCO2 Frequency', '05: DCO2 Pulse Width', '06: DCO2 Waveshape',
'07: Mix Level',
'08: VCF FM Amount', '09: VCF Frequency', '10: VCF Resonance',
'11: VCA1 Level', '12: VCA2 Level',
'13: Env1 Delay', '14: Env1 Attack', '15: Env1 Decay', '16: Env1 Release', '17: Env1 Amplitude',
'18: Env2 Delay', '19: Env2 Attack', '20: Env2 Decay', '21: Env2 Release', '22: Env2 Amplitude',
'23: Env3 Delay', '24: Env3 Attack', '25: Env3 Decay', '26: Env3 Release', '27: Env3 Amplitude',
'28: LFO1 Speed', '29: LFO1 Amplitude', '30: LFO2 Speed', '31: LFO2 Amplitude',
'32: Portamento Time');

# Matrix-1000 default basic patch data
my @basicpat=(
66,78,75,48,58,32,48,48,00,00,31,31,03,02,00,31,24,03,01,02,
31,00,00,02,00,00,55,00,00,02,00,63,00,00,00,40,00,00,00,00,
'09: Keyboard',00,30,00,00,00,00,'09: Keyboard',00,00,00,00,10,50,10,40,00,00,00,00,
00,10,50,10,40,00,00,00,00,00,20,00,20,40,00,00,'09: Keyboard',00,15,31,
47,63,00,00,00,00,00,00,00,00,42,00,00,63,63,63,63,63,63,00,
00,00,00,00,'17: Pedal 2',00,'16: Env1 Release','17: Pedal 2',00,'21: Env2 Release',
'11: Tracking Gen.',00,'09: VCF Frequency','20: Lever 3',00,'08: VCF FM Amount',
'00: Unused',00,'00: Unused','00: Unused',00,'00: Unused','00: Unused',00,'00: Unused',
'00: Unused',00,'00: Unused','00: Unused',00,'00: Unused','00: Unused',00,'00: Unused');
@PData=@basicpat;
PData2Name();

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
my $outtest;
my $readfrom;
my $dumpto;
my $midiupload;
my $midi_settings;
my $editbufferops;

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
my $ModMatrix_frame;

# set up main program window
my $mw=MainWindow->new();
$mw->title($titlestring);
$mw->resizable(0,0);
#$mw->focusFollowsMouse;

$mw->fontCreate('title', -family=>'Sans', -weight=>'bold', -size=>9);

$mw->DefineBitmap('bm:darrow'  =>11,10,$darrow_bits);
$mw->DefineBitmap('bm:triangle'=>17, 9,$triangle_bits);
$mw->DefineBitmap('bm:upsaw'   =>17, 9,$upsaw_bits);
$mw->DefineBitmap('bm:downsaw' =>17, 9,$downsaw_bits);
$mw->DefineBitmap('bm:square'  =>17, 9,$square_bits);
$mw->DefineBitmap('bm:random'  =>17, 9,$random_bits);
$mw->DefineBitmap('bm:noise'   =>17, 9,$noise_bits);
$mw->DefineBitmap('bm:sampled' =>17, 9,$sampled_bits);

# catch users pressing the window close button
$mw->protocol(WM_DELETE_WINDOW => \&exitProgam );

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
if ($LINUX) {$mw->optionAdd('*Scrollbar.Width', 10, 99);}
# set default button properties
$mw->optionAdd('*Button.borderWidth', 1, 99);
$mw->optionAdd('*Button.highlightThickness', 0, 99);
$mw->optionAdd('*Checkbutton.borderWidth', 1, 99);
# set default canvas properties
$mw->optionAdd('*Canvas.highlightThickness', 0, 99);
# global shortcuts
$mw->bind($mw, "<Alt-a>"    =>\&About);
$mw->bind($mw, "<Control-q>"=>\&exitProgam);
$mw->bind($mw, "<Control-a>"=>\&saveasFile);
$mw->bind($mw, "<Control-s>"=>\&saveFile);
$mw->bind($mw, "<Control-o>"=>\&loadFile);
$mw->bind($mw, "<Control-n>"=>\&newVoice);

# create main window layout
my $MBar   =$mw->Frame(%MBar_defaults)->pack(-side=>'top', -fill=>'x', -anchor=>'n', -expand=>1);
topMenubar(\$MBar);
my $Col_0  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_1  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_2  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_34b=$mw->Frame()->pack(-side=>'bottom', -fill=>'x');
my $Col_3  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
my $Col_4  =$mw->Frame()->pack(-side=>'left',   -fill=>'y', -anchor=>'n');
# Column 0
$DCO_frame[0]   = $Col_0->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
DCO_Frame(0);
$LFO_frame[0]   = $Col_0->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>0, -anchor =>'s');
LFO_Frame(0);
$Ramp_frame[0]  = $Col_0->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>0, -anchor =>'s');
Ramp_Frame(0);
# Column 1
$DCO_frame[1]   = $Col_1->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
DCO_Frame(1);
$LFO_frame[1]   = $Col_1->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>0, -anchor =>'s');
LFO_Frame(1);
$Ramp_frame[1]  = $Col_1->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>0, -anchor =>'s');
Ramp_Frame(1);
# Column 2
$Env_frame[0]   = $Col_2->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>0, -anchor =>'n');
Env_Frame(0);
$VCF_frame      = $Col_2->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
VCF_Frame();
$FM_frame       = $Col_2->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
FM_Frame();
# Column 3
$Env_frame[1]   = $Col_3->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>1, -anchor =>'n');
Env_Frame(1);
$VCA_frame      = $Col_3->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
VCA_Frame();
$Porta_frame    = $Col_3->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
Porta_Frame();
# Column 4
$Env_frame[2]   = $Col_4->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'x', -expand=>1, -anchor =>'n');
Env_Frame(2);
$TrGen_frame    = $Col_4->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
TrGen_Frame();
$Keybmode_frame = $Col_4->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
Keybmode_Frame();
# Column 3+4 bottom
$midi_settings  = $Col_34b->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
MIDI_IOconfig();
$editbufferops  = $Col_34b->Frame(%Frame_defaults)->pack(-side=>'top', -fill=>'both', -expand=>1);
EditBufferOps();
# Modulation Matrix Window
$ModMatrix_frame=$mw->Toplevel(-title=>'Modulation Matrix');
$ModMatrix_frame->protocol(WM_DELETE_WINDOW => \&Noop );
$ModMatrix_frame->resizable(0,0);
ModMatrix_Frame();


MainLoop;


# -----------
# Subroutines
# -----------

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

# Do nothing
sub Noop {}

# call as: UnsavedChanges($question), returns: Yes/No
sub UnsavedChanges {
    my ($question)=@_;
    my $rtn=$mw->messageBox(
        -title   => 'Unsaved changes',
        -icon    => 'question',
        -message => "There are unsaved changes that will be lost unless you save them first.\n\n$question",
        -type    => 'YesNo',
        -default => 'No'
    );
    return $rtn;
}

# Error popup window
sub Error {
    my ($win, $msg)=@_;
    ${$win}->messageBox(
        -title   =>'Error',
        -icon    => 'warning',
        -message =>"$msg",
        -type    =>'Ok',
        -default =>'Ok'
    );
}

# set up top menu bar with keyboard bindings
sub topMenubar {
    my ($frame)=@_;
    my $btn0=$$frame->Menubutton(-text=>'File', -underline=>0, -tearoff=>0, -anchor=>'w',
        -menuitems => [['command'=>'New',        -accelerator=>'Ctrl+N', -command=>\&newVoice   ],
                       ['command'=>'Open...',    -accelerator=>'Ctrl+O', -command=>\&loadFile   ],
                       "-",
                       ['command'=>'Save',       -accelerator=>'Ctrl+S', -command=>\&saveFile   ],
                       ['command'=>'Save As...', -accelerator=>'Ctrl+A', -command=>\&saveasFile ],
                       "-",
                       ['command'=>'Quit',       -accelerator=>'Ctrl+Q', -command=>\&exitProgam ]]
    )->pack(-side=>'left');

    my $btn2=$$frame->Menubutton(-text=>'Help', -underline=>0, -tearoff=>0, -anchor=>'w',
        -menuitems => [['command'=>'About',      -accelerator=>'Alt+A',  -command=>\&About, -underline=>0]]
    )->pack(-side=>'left');

    # Unison Detune Slider
    my $detune=$$frame->Frame()->pack(-side=>'right');
    $detune->Label(-text=>'Unison detune: ', -font=>'Sans 10')->pack(-side=>'left');
    $detune->Scale(
        -variable     => \$det_val,
        -to           => 127,
        -from         => 0,
        -resolution   => 1,
        -tickinterval => 20,
        -width        => 8,
        -length       => 180,
        -sliderlength => 20,
        -borderwidth  => 1,
        -troughcolor  => 'darkgrey',
        -highlightthickness => 0,
        -showvalue    => 0,
        -font         => $f1,
        -cursor       => 'hand2',
        -orient       => 'horizontal',
        -command      => sub{ SendCC($dev_nr-1,94,$det_val); }
    )->pack(-side=>'left');

    # Patch Name
    # patch name window width: 10 for Linux, 15 for Windows
    my $vcn_width; my $pad_width;
    if ($WINDOWS) { $vcn_width=15; $pad_width=120} else { $vcn_width=10; $pad_width=110}

    my $vname=$$frame->Frame()->pack(-side=>'right');
    $vname->Label(-text=>'Patch Name: ', -font=>'Sans 10')->pack(-side=>'left');
    $vname->Entry(%Entry_defaults,
        -width           => $vcn_width,
        -font            => 'Fixed 10',
        -validate        => 'key',
        -justify         => 'center',
        -validatecommand => sub {$_[0]=~/^[\x20-\x7F]{0,8}$/},
        -invalidcommand  => sub {},
        -textvariable    => \$voice_name
    )->pack(-side=>'left');
    $vname->Label(-font=>'Sans 10',-padx=>$pad_width)->pack(-side=>'left');
}

# 'About' information window
sub About {
    $mw->messageBox(
        -title   => 'About - M1000 Manager',
        -icon    => 'info',
        -message => "             M1000 Manager v. $version\n\nA Patch Editor for the Oberheim Matrix-1000\n
            \x{00A9} $year LinuxTECH.NET\n\nOberheim is a registered trademark of Gibson Guitar Corp.",
        -type    => 'Ok',
        -default => 'Ok'
    );
}

# Reset Patch to default Basic Patch
sub newVoice {
    my $rtn="";
    if ($modified == 1) {
        $rtn=UnsavedChanges('Reset Patch to default values anyway?');
    }
    if (($rtn eq "Yes") or ($modified == 0)) {
        for (my $i = 0; $i < 134; $i++) {
            $PData[$i]=$basicpat[$i];
        }
        $modified=0;
        $filename='';
        $mw->title($titlestring);
        $patnr=0;
        PData2Name();
        if ($midi_outdev ne '') { SysexPatSend(); }
    }
}

# load a Matrix 1000 voice sysex dump file
sub loadFile {
    my $rtn="";
    if ($modified == 1) {
        $rtn=UnsavedChanges('Open new file anyway?');
    }
    if (($rtn eq "Yes") or ($modified == 0)) {
        my $types=[ ['Sysex Files', ['.syx', '.SYX']], ['All Files', '*'] ];
        my $syx_file=$mw->getOpenFile(
            -defaultextension => '.syx',
            -filetypes        => $types,
            -title            => 'Open a Matrix 1000 Voice Dump Sysex file'
        );
        if ($syx_file && -r $syx_file) {
            open my $fh, '<', $syx_file;
            binmode $fh;
            my $sysex = do { local $/; <$fh> };
            close $fh;
            my $check=ValidatePatData(\$sysex);
            if ($check ne 'ok') {
                Error(\$mw, "Error while opening $syx_file\n\n$check");
            } else {
                ReadPatData(substr($sysex,5,268));
                $patnr=ord(substr($sysex,4,1));
                $modified=0;
                $filename=$syx_file;
                $mw->title("$titlestring - $filename");
                if ($midi_outdev ne '') { SysexPatSend(); }
            }
        } elsif ($syx_file) {
            Error(\$mw,"Error: could not open $syx_file");
        }
    }
}

# save Matrix 1000 voice to previously opened voice sysex dump file
sub saveFile {
    if ($filename ne '') {
        saveSub($filename);
    } else {
        saveasFile();
    }
}

# save Matrix 1000 voice to single voice sysex dump file
sub saveasFile {
    my $types=[ ['Sysex Files', ['.syx', '.SYX']], ['All Files', '*'] ];
    my $syx_file=$mw->getSaveFile(
        -defaultextension => '.syx',
        -filetypes        => $types,
        -title            => 'Save as'
    );
    if ($syx_file && ($syx_file ne '')) {
        saveSub($syx_file);
    }
}

# actual voice sysex dump file save subroutine
sub saveSub {
    my($fname)=@_;
    if ($fname eq '') {
        Error(\$mw,"Error: no file name given.");
        return;
    } else {
        my $fh;
        unless (open $fh, '>', $fname) {
            Error(\$mw,"Error: cannot save to file $fname\nCheck filesystem permissions.");
            return;
        }
        my $sysex=WritePatData();
        my $chksum=chksumCalc(\$sysex);
        $sysex="\xF0\x10\x06\x01" . chr($patnr) . $sysex . chr($chksum) . "\xF7";
        binmode $fh;
        print $fh $sysex;
        close $fh;
        $modified=0;
        $filename=$fname;
        $mw->title("$titlestring - $filename");
    }
}

# Calculate checksum of M1000 sysex data
sub chksumCalc {
    my($ref_sysexdata)=@_;
    my $chksum=0;
    for (my $i = 0; $i < 268; $i+=2) {
        $chksum+=(ord(substr(${$ref_sysexdata},$i,1))+(ord(substr(${$ref_sysexdata},$i+1,1))*16));
    }
    return ($chksum%128);
}

# Validates Matrix 1000 single patch format
sub ValidatePatData {
    my($ref_patch)=@_;
    # Format: F0 10 06 01 <patch nr> <268 bytes of patch data> <checksum> F7
    ${$ref_patch}=~/^\xF0\x10\x06\x01[\x00-\x63][\x00-\x0F]{268}[\x00-\x7F]\xF7$/ or return "invalid sysex data";
    # calculate checksum
    my $calcsum=chksumCalc(\(substr(${$ref_patch},5,268)));
    # expected checksum
    my $syxsum=(ord(substr(${$ref_patch},273,1)));
    # compare
    ($calcsum == $syxsum) or return "sysex checksum mismatch";
    return "ok";
}

# Reads Matrix 1000 patch data from sysex data string into @PData
sub ReadPatData {
    my($patdata)=@_;

    for (my $i = 0; $i < 268; $i+=2) {
        my $n=($i/2);
        my $v=(ord(substr($patdata,$i,1))+(ord(substr($patdata,$i+1,1))*16));
        print STDOUT "$n => ($v) "; # for debug purposes
        if ($n=~'^(40|47|76|104|107|110|113|116|119|122|125|128|131)$') {
            if ($v > 20) { 
                Error(\$mw,"Warning:\nByte $n value out of range ($v).\nSetting it to '0'.");
                $v=0;
            }
            $PData[$n]=($mod_sources[$v]); # decode mod sources
        } elsif ($n=~'^(106|109|112|115|118|121|124|127|130|133)$') {
            if ($v > 32) {
                Error(\$mw,"Warning:\nByte $n value out of range ($v).\nSetting it to '0'.");
                $v=0;
            }
            $PData[$n]=($mod_dest[$v]); # decode mod destinations
        } elsif (($n==19) or ($n>=86 and $n<=103) or
                 ($n=~'^(105|108|111|114|117|120|123|126|129|132)$')) {
            if ($v > 63){ $v=($v-256); } # decode negative values
            $PData[$n]=$v;
        } else {
            $PData[$n]=$v;
        }
        print STDOUT "$PData[$n]\n"; # for debug purposes
    }
    PData2Name();
}

# Returns 268 byte string in Matrix 1000 single patch format
sub WritePatData {
    Name2PData();
    my $sysex="";
    for (my $i = 0; $i < 134; $i++) {
        my $dtmp=0;
        if (($i=~'^(40|47|76|104|107|110|113|116|119|122|125|128|131)$') or
            ($i=~'^(106|109|112|115|118|121|124|127|130|133)$')) {
            ($dtmp)=($PData[$i]=~/^(\d\d):.*/); # extract mod src/dest number
        } else {
            $dtmp=($PData[$i]);
            if ($dtmp < 0) { $dtmp=256+$dtmp; } # encode negative values
        }
        $sysex.=chr($dtmp%16).chr(int($dtmp/16));
    }
    return $sysex;
}

# Updates @PData with patch name from $voice_name
sub Name2PData {
    for (my $i = 0; $i < 8; $i++) {
        $PData[$i]=ord(substr($voice_name,$i,1));
    }
}

# Updates $voice_name with patch name from @PData
sub PData2Name {
    $voice_name='';
    for (my $i = 0; $i < 8; $i++) {
        $voice_name.=chr($PData[$i]);
    }
}

#------------------------------------------------------------------------------------------------
# MIDI Subroutines

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
        $readfrom->configure(-state=>'active');
    } else {
        $readfrom->configure(-state=>'disabled');
    }
    if ($midi_outdev ne '') {
        $outtest->configure(-state=>'active');
        $dumpto->configure(-state=>'active');
    } else {
        $outtest->configure(-state=>'disabled');
        $dumpto->configure(-state=>'disabled');
    }
}

# MIDI input and output devices selection
sub MIDI_IOconfig {
    $midi_settings->Label(%TitleLbl_defaults, -text=> 'MIDI Configuration'
    )->pack(-fill=>'x', -expand=>1, -anchor=>'n');

    my $subframe=$midi_settings->Frame(%Default_FrBGCol,
    )->pack(-fill=>'x', -expand=>1, -pady=>6);

    # MIDI OUT device selection
    $subframe->Label(%Label_defaults,
        -text         => "Output MIDI Device: ",
        -font         => 'Sans 9',
        -justify      => 'right'
    )->grid(-row=>0, -column=>0, -sticky=>'e', -pady=>4);

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
    )->grid(-row=>0, -column=>1, -sticky=>'w', -pady=>4);

    $midiout->Subwidget("choices")->configure(%choices_defaults);
    $midiout->Subwidget("arrow")->configure(%arrow_defaults);

    if (!$LINUX && !$WINDOWS) { $midiout->configure(-state=>'disabled'); }

    $outtest=$subframe->Button(
        -font         => 'Sans 9',
        -text         => 'Test',
        -pady         => 0
    )->grid(-row=>0, -column=>2, -sticky=>'w', -padx=>8);

    $outtest->bind('<Button-1>' => sub { PlayMidiNote($dev_nr-1,64,127,1); });
    $outtest->bind('<ButtonRelease-1>' => sub { PlayMidiNote($dev_nr-1,64,127,0); });

    if ($midi_outdev ne '') {
        $outtest->configure(-state=>'active');
    } else {
        $outtest->configure(-state=>'disabled');
    }

    # MIDI IN device selection
    $subframe->Label(%Label_defaults,
        -text         => "Input MIDI Device: ",
        -font         => 'Sans 9',
        -justify      => 'right'
    )->grid(-row=>1, -column=>0, -sticky=>'e', -pady=>4);

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
    )->grid(-row=>1, -column=>1, -sticky=>'w', -pady=>4);

    $midiin->Subwidget("choices")->configure(%choices_defaults);
    $midiin->Subwidget("arrow")->configure(%arrow_defaults);

    if (!$LINUX) { $midiin->configure(-state=>'disabled'); }

    $subframe->Label(%Label_defaults,
        -text         => "MIDI Ch: ",
        -font         => 'Sans 9',
        -justify      => 'right'
    )->grid(-row=>1, -column=>2, -sticky=>'e', -pady=>4);

    $subframe->Spinbox(%Entry_defaults,
        -width        =>  2,
        -justify      => 'center',
        -font         => 'Sans 9',
        -textvariable =>  \$dev_nr,
        -to           =>  16,
        -from         =>  1,
        -increment    =>  1,
        -state        => 'readonly',
        -readonlybackground => $LCDbg
    )->grid(-row=>1, -column=>3, -sticky=>'w', -pady=>4);

}

# Edit Buffer Operation Buttons (Write, Read Store)
sub EditBufferOps {
    $editbufferops->Label(%Label_defaults,
        -font         => 'Sans 9',
        -text         => 'Matrix-1000 Edit Buffer: ',
        -justify      => 'right'
    )->grid(-row=>1, -column=>1, -padx=>4, -pady=>2);

    $dumpto=$editbufferops->Button(
        -font         => 'Sans 9',
        -text         => 'Dump to',
        -pady         => 0,
        -command      => sub{ SysexPatSend(); }
    )->grid(-row=>1, -column=>2, -padx=>4, -pady=>2);

    if ($midi_outdev ne '') {
        $dumpto->configure(-state=>'active');
    } else {
        $dumpto->configure(-state=>'disabled');
    }

    $readfrom=$editbufferops->Button(
        -font         => 'Sans 9',
        -text         => 'Read from',
        -pady         => 0,
        -command      => sub{ SysexPatRcve(); }
    )->grid(-row=>1, -column=>3, -padx=>4, -pady=>2);

    if (($midi_indev ne '') && ($midi_outdev ne '')) {
        $readfrom->configure(-state=>'active');
    } else {
        $readfrom->configure(-state=>'disabled');
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

# Send CC
sub SendCC {
    my $ch=$_[0]; # midi channel 0-15
    my $cc=$_[1]; # continuous controller 0-127
    my $vl=$_[2]; # note value 0-127

    if ($LINUX) {
        MIDI::ALSA::output(MIDI::ALSA::controllerevent( $ch, $cc, $vl));
    } elsif ($WINDOWS && ($midi_outdev ne '')) {
        my $msg=($vl*65536)+($cc*256)+(176+$ch);
        $midiOut->ShortMsg($msg);
    }
}

# send Patch Parameter Change Message (real time sysex) to Matrix-1000
sub SendPaChMsg {
    my($param, $value)=@_;
    my $ddata='';

    if ($midi_outdev ne '') {                       # only proced if MIDI OUT device is set
        until ($midilock == 0) { usleep(1); };      # wait until preceding par changes are done
        $midilock=1;                                # lock out other par change attempts
        if ($param < 100) {                         # deal with normal parameters
            if ($value < 0){ $value=$value+128; }   # handle negative values correctly
            $ddata="\x10\x06\x06".chr($param).chr($value);
            print STDOUT "par:[$param] val:[$value]\n"; # for debug purposes
        } else {                                    # Mod Matrix parameters need special handling
            my $p=($param-100);
            my $n=($p*3);
            my ($src)=($PData[(104+$n)]=~/^(\d\d):.*/);
            my  $val = $PData[(105+$n)];
            my ($dst)=($PData[(106+$n)]=~/^(\d\d):.*/);
            if ($val < 0){ $val=$val+128; }
            $ddata="\x10\x06\x0B".chr($p).chr($src).chr($val).chr($dst);
            print STDOUT "MM:[$p] src:[$src] val:[$val] dst:[$dst]\n"; # for debug purposes
        }
        # Enforce 20 ms gap since last par change msg sent
        my $midinow=time;
        my $gap=($midinow - $midilast);
        if ($gap < 0.02) {
            usleep ((0.02 - $gap) * 1000000 );
        }
        print STDOUT time ."\n";                    # for debug purposes
        # Send the MIDI data to the synth

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
        $midilast=time;    # store timestamp
        $midilock=0;       # allow other par changes to proceed
    }
}

# send sysex dump of current patch in editor to M1000 edit buffer via MIDI
sub SysexPatSend {
    my $sysex=WritePatData();
    my $chksum=chksumCalc(\$sysex);
    $sysex="\x10\x06\x0D\x00" . $sysex . chr($chksum);

    if ($LINUX and ($midi_outdev ne '')) {
        MIDI::ALSA::output( MIDI::ALSA::sysex( $dev_nr-1, $sysex, 0 ) );
        MIDI::ALSA::syncoutput();
    } elsif ($WINDOWS and ($midi_outdev ne '')) {
        my $buf="\xF0" . $sysex . "\xF7";
        my $midihdr = pack ("PLLLLPLL", $buf, length $buf, 0, 0, 0, undef, 0, 0);
        my $lpMidiOutHdr = unpack('L!', pack('P', $midihdr));
        $midiOut->PrepareHeader($lpMidiOutHdr);
        $midiOut->LongMsg($lpMidiOutHdr);
        $midiOut->UnprepareHeader($lpMidiOutHdr);
    }
}

# request and receive a sysex dump from edit buffer of the M1000 via MIDI
sub SysexPatRcve {
    my $tmp_dump='';
    if ($LINUX and ($midi_outdev ne '') and ($midi_indev ne '')) {
        MIDI::ALSA::output(MIDI::ALSA::sysex($dev_nr-1, "\x10\x06\x04\x04\x00", 0));
        while (1) {
            # read next ALSA input event
            my @alsaevent=MIDI::ALSA::input();
            # if the input connection has disappeared then exit
            if ( $alsaevent[0] == SND_SEQ_EVENT_PORT_UNSUBSCRIBED() ) {
                Error(\$mw,"Error: MIDI connection dropped.");
                return '';
            }
            # if we have received a sysex input event then do this
            elsif ( $alsaevent[0] == SND_SEQ_EVENT_SYSEX() ) {
                # save event data array
                my @data=@{$alsaevent[7]};
                # append sysex data chunk to $sysex_dump
                $tmp_dump=$tmp_dump.$data[0];
                # if last byte is F7 then sysex dump is complete
                if ( substr($data[0],-1) eq chr(247) ) {
                    last;
                }
            }
        }
    } elsif ($WINDOWS) {
        # add Windows specific code here
    }
    my $check=ValidatePatData(\$tmp_dump);
    if ($check ne 'ok') {
        Error(\$mw, "Error while receiving dump\n\n$check");
    } else {
        ReadPatData(substr($tmp_dump,5,268));
        $patnr=ord(substr($tmp_dump,4,1));
        $modified=0;
        $filename='';
        $mw->title("$titlestring");
    }
}

#------------------------------------------------------------------------------------------------
# Standard GUI Elements

# Subframe with header, returns Subframe created
sub StdFrame {
    my($frame, $title)=@_;

    $$frame->Label(%TitleLbl_defaults,
        -text=>$title
    )->pack(-fill=>'x', -expand=>1, -anchor=>'n');

    my $subframe=$$frame->Frame(%Default_FrBGCol
    )->pack(-fill=>'x', -expand=>1, -anchor=>'n', -padx=>4, -pady=>4);

    return $subframe;
}

# Horizontal Slider, returns Scale and Spinbox created
sub StdSlider {
    my($frame, $var, $from, $to, $intv, $incr, $param, $label, $nofr, $transf)=@_;
    if (! $transf) {$transf=''}

    my $sf;
    # create wrapper frame unless $nofr is set
    if (! $nofr) {
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(%GridConf,-columnspan=>2);
    } else {
        $sf=$$frame;
    }

    my $scale=$sf->Scale(%Scale_defaults,
        -variable     =>  $var,
        -to           =>  $to,
        -from         =>  $from,
        -resolution   =>  $incr,
        -tickinterval =>  $intv,
        -label        =>  $label,
        -command      => sub{ SendPaChMsg($param,(eval"$$var$transf")); }
    )->grid(
    my $spinbox=$sf->Spinbox(%Entry_defaults,
        -width        =>  3,
        -justify      => 'center',
        -font         => 'Sans 10',
        -textvariable =>  $var,
        -to           =>  $to,
        -from         =>  $from,
        -increment    =>  $incr,
        -state        => 'readonly',
        -readonlybackground => $LCDbg,
        -command      => sub{ SendPaChMsg($param,(eval"$$var$transf")); }
    ), -padx=>1, -pady=>3, -sticky =>'s');

    # Spinbox mousewheel support for Windows (Linux has it by default)
    if ($WINDOWS) {
        $spinbox->bind(
            '<MouseWheel>',
            [
                sub {
                    my $dir=($_[1] > 0 ? 'buttonup' : 'buttondown');
                    $spinbox->invoke($dir);
                },
                Ev('D')
            ]
        );
    }

    return ($scale,$spinbox);
}

# Radiobuttons with Labels and Title
sub OptSelect {
    my ($frame, $var, $options, $parm, $btnwidth, $desc, $nofr)=@_;
    my $sf;
    my $optnr=(@{$options});

    # create wrapper frame unless $nofr is set
    if (! $nofr) {
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(%GridConf,-columnspan=>2);
    } else {
        $sf=$$frame;
    }
    if ($desc) { 
        $sf->Label(%Label_defaults,
            -text     => $desc
        )->grid(-row=>0, -columnspan=>$optnr);
    }
    for (my $n=0; $n<$optnr; $n++) {
        my %label=();
        if (substr($$options[$n],0,3) eq 'bm:') {
            %label=(-bitmap => $$options[$n],-height=>15); 
        } else {
            %label=(-text   => $$options[$n]);
        }
        $sf->Radiobutton(%RadioB_defaults, %label,
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
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(%GridConf,-columnspan=>2);
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
        -font         => 'Sans 8',
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
        $sf=$$frame->Frame(%Default_FrBGCol)->grid(%GridConf,-columnspan=>2, -pady=>1);
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

#------------------------------------------------------------------------------------------------
# Editor Frames

sub DCO_Frame {
    my($osc)=@_;
    my $m=($osc*10);
    my $n=($osc*5);
    my $t=($osc*2);
    my $subframe=StdFrame(\$DCO_frame[$osc],'Oscillator (DCO) '.($osc+1));
    my @DCO_wavsel_label;
    if (!$osc) { @DCO_wavsel_label=('off', 'pulse', 'wave', 'both'); }           # DCO 1
    else       { @DCO_wavsel_label=('off', 'pulse', 'wave', 'both', 'noise'); }  # DCO 2
    OptSelect(   \$subframe, \$PData[(13+$n)],  \@DCO_wavsel_label, (6+$m),  6, 'Oscillator Waveform:');
    OnOffSwitch( \$subframe, \$PData[(22+$t)],                      (9+$m),     'Key Click: ');
    StdSlider(   \$subframe, \$PData[(10+$n)],       0,  63,$sp, 1, (5+$m),     'Wave Shape (0=saw -> 63=triangle)');
    StdSlider(   \$subframe, \$PData[(11+$n)],       0,  63,$sp, 1, (3+$m),     'Pulse Width (31=square)');
    StdSlider(   \$subframe, \$PData[(87+$t)],     -63,  63,$sn, 1, (4+$m),     'Pulse Width modulation by LFO 2');
    StdSlider(   \$subframe, \$PData[( 9+$n)],       0,  63,$sp, 1, (0+$m),     'Frequency (semi-tone increments)');
    StdSlider(   \$subframe, \$PData[(86+$t)],     -63,  63,$sn, 1, (1+$m),     'Frequency modulation by LFO 1');
    if (!$osc) {
     my @DCO1_sync_label=('off', 'soft', 'medium', 'hard');
     OptSelect(  \$subframe, \$PData[ 25],      \@DCO1_sync_label,       2,  8, 'DCO Synchronization:');
    } else {
     StdSlider(  \$subframe, \$PData[ 19],         -31,  31,$s3, 1,     12,     'Detune DCO 2 relative to DCO 1');
    }
    my @DCO_levers_label=('off', 'p.bend', 'vibrato', 'both');
    OptSelect(   \$subframe, \$PData[(12+$n)],  \@DCO_levers_label, (7+$m),  8, 'Fixed Modulations:');
    if (!$osc) {
     OnOffSwitch(\$subframe, \$PData[ 21],                               8,     'Portamento: '); }
    else {
     my @DCO2_porta_label=('none', 'portam.', 'kb.track');
     OptSelect(  \$subframe, \$PData[ 23],      \@DCO2_porta_label,     18,  8, '');
    }
}

sub VCF_Frame {
    my $subframe=StdFrame(\$VCF_frame,'24dB LP Filter (VCF)');
    StdSlider(   \$subframe, \$PData[ 20],           0,  63,$sp, 1,     20,     'Balance (DCO 2 <---31---> DCO 1)');
    StdSlider(   \$subframe, \$PData[ 26],           0, 127,$s7, 1,     21,     'Cutoff Frequency');
    StdSlider(   \$subframe, \$PData[ 27],           0,  63,$sp, 1,     24,     'Resonance');
    StdSlider(   \$subframe, \$PData[ 90],         -63,  63,$sn, 1,     22,     'Frequency modulation by ENV 1');
    StdSlider(   \$subframe, \$PData[ 91],         -63,  63,$sn, 1,     23,     'Frequency modulation by Aftertouch');
    my @VCF_levers_label=('off', 'p.bend', 'vibrato', 'both');
    OptSelect(   \$subframe, \$PData[ 28],  \@VCF_levers_label,         25,  8, 'Frequency modulation by:');
    my @VCF_porta_label=('none', 'portam.', 'kb.track');
    OptSelect(   \$subframe, \$PData[ 29],   \@VCF_porta_label,         26,  8, '');
}

sub VCA_Frame {
    my $subframe=StdFrame(\$VCA_frame,'Two-Stage Amplifier (VCA 1 + 2)');
    StdSlider(   \$subframe, \$PData[ 31],           0,  63,$sp, 1,     27,     'VCA 1 Volume');
    StdSlider(   \$subframe, \$PData[ 92],         -63,  63,$sn, 1,     28,     'VCA 1 modulation by Velocity');
    StdSlider(   \$subframe, \$PData[ 93],         -63,  63,$sn, 1,     29,     'VCA 2 modulation by ENV 2');
}

sub FM_Frame {
    my $subframe=StdFrame(\$FM_frame,'FM');
    StdSlider(   \$subframe, \$PData[ 30],           0,  63,$sp, 1,     30,     'VCF FM amount');
    StdSlider(   \$subframe, \$PData[100],         -63,  63,$sn, 1,     31,     'FM modulation by ENV 3');
    StdSlider(   \$subframe, \$PData[101],         -63,  63,$sn, 1,     32,     'FM modulation by Aftertouch');
}

sub TrGen_Frame {
    my $subframe=StdFrame(\$TrGen_frame,'Tracking Generator');
    PullDwnMenu( \$subframe, \$PData[ 76],      \@mod_sources,          33, 18, 'Tracking source:');
    StdSlider(   \$subframe, \$PData[ 77],           0,  63,$sp, 1,     34,     'Tracking Point 1 (0=neutral)');
    StdSlider(   \$subframe, \$PData[ 78],           0,  63,$sp, 1,     35,     'Tracking Point 2 (15=neutral)');
    StdSlider(   \$subframe, \$PData[ 79],           0,  63,$sp, 1,     36,     'Tracking Point 3 (31=neutral)');
    StdSlider(   \$subframe, \$PData[ 80],           0,  63,$sp, 1,     37,     'Tracking Point 4 (47=neutral)');
    StdSlider(   \$subframe, \$PData[ 81],           0,  63,$sp, 1,     38,     'Tracking Point 5 (63=neutral)');
}

sub Ramp_Frame {
    my($ramp)=@_;
    my $m=($ramp*2);
    my $subframe=StdFrame(\$Ramp_frame[$ramp],'Ramp Generator '.($ramp+1));
    StdSlider(   \$subframe, \$PData[(82+$m)],       0,  63,$sp, 1,(40+$m),     'Rate');
    my @RampTRG_label=('single', 'multi', 'external', 'gated ext');
    OptSelect(   \$subframe, \$PData[(83+$m)],  \@RampTRG_label,   (41+$m),  8, 'Ramp trigger type:');
}

sub Porta_Frame {
    my $subframe=StdFrame(\$Porta_frame,'Portamento');
    StdSlider(   \$subframe, \$PData[ 32],           0,  63,$sp, 1,     44,     'Portamento Rate (transition time)');
    StdSlider(   \$subframe, \$PData[ 99],         -63,  63,$sn, 1,     45,     'Portamento modulation by Velocity');
    my @Portamode_label=('linear', 'constant', 'exponential');
    OptSelect(   \$subframe, \$PData[ 33],   \@Portamode_label,         46, 10, 'Portamento Mode:');
    OnOffSwitch( \$subframe, \$PData[ 34],                              47,     'Legato Portamento: ');
}

sub Keybmode_Frame {
    my $subframe=StdFrame(\$Keybmode_frame,'Keyboard Mode');
    my @Keybmode_label=('reassign', 'rotate', 'unison', 'reas+rob');
    OptSelect(   \$subframe, \$PData[  8],   \@Keybmode_label,          48,  8, 'Keyboard Mode:');
}

sub Env_Frame {
    my($env)=@_;
    my $m=($env*10);
    my $n=($env*9);
    my $subframe=StdFrame(\$Env_frame[$env],'Envelope '.($env+1));
    my @EnvMod_label=('normal', 'DADR', 'freerun', 'both');
    OptSelect(   \$subframe, \$PData[(57+$n)],  \@EnvMod_label,    (58+$m),  7, 'Envelope Mode:');
    StdSlider(   \$subframe, \$PData[(50+$n)],       0,  63,$sp, 1,(50+$m),     'Initial Delay Time');
    StdSlider(   \$subframe, \$PData[(51+$n)],       0,  63,$sp, 1,(51+$m),     'Attack Time');
    StdSlider(   \$subframe, \$PData[(52+$n)],       0,  63,$sp, 1,(52+$m),     'Decay Time');
    StdSlider(   \$subframe, \$PData[(53+$n)],       0,  63,$sp, 1,(53+$m),     'Sustain Level');
    StdSlider(   \$subframe, \$PData[(54+$n)],       0,  63,$sp, 1,(54+$m),     'Release Time');
    StdSlider(   \$subframe, \$PData[(55+$n)],       0,  63,$sp, 1,(55+$m),     'Amplitude Level');
    StdSlider(   \$subframe, \$PData[(94+$env)],   -63,  63,$sn, 1,(56+$m),     'Amplitude modulation by Velocity');
    my @TrgMod_label=('KST', 'KSR', 'KMT', 'KMR', 'XST', 'XSR', 'XMT', 'XMR');
    OptSelect(   \$subframe, \$PData[(49+$n)],  \@TrgMod_label,    (57+$m),  4, 'Trigger Mode:');
    my @LFOTrg_label=('off', 'LFO 1', 'G-LFO 1');
    OptSelect(   \$subframe, \$PData[(56+$n)],  \@LFOTrg_label,    (59+$m),  9, 'LFO 1 Trigger:');
}

sub LFO_Frame {
    my($lfo)=@_;
    my $m=($lfo*10);
    my $n=($lfo*7);
    my $txt;
    my $subframe=StdFrame(\$LFO_frame[$lfo],'LFO '.($lfo+1));
    my @LFOWav_label=("bm:triangle", "bm:upsaw", "bm:downsaw", "bm:square", "bm:random", "bm:noise", "bm:sampled");
    OptSelect(   \$subframe, \$PData[(38+$n)],  \@LFOWav_label,    (82+$m), 23, 'Waveform:');
    OnOffSwitch( \$subframe, \$PData[(37+$n)],                     (87+$m),     'Lag: ');
    PullDwnMenu( \$subframe, \$PData[(40+$n)],  \@mod_sources,     (88+$m), 18, 'Sample source:');
    StdSlider(   \$subframe, \$PData[(35+$n)],       0,  63,$sp, 1,(80+$m),     'Speed (frequency)');
    if (!$lfo) { $txt='Aftertouch'; } else { $txt='Keyboard'; }
    StdSlider(   \$subframe, \$PData[(102+$lfo)],  -63,  63,$sn, 1,(81+$m),     'Speed modulation by '.$txt);
    StdSlider(   \$subframe, \$PData[(41+$n)],       0,  63,$sp, 1,(84+$m),     'Amplitude');
    StdSlider(   \$subframe, \$PData[(97+$lfo)],   -63,  63,$sn, 1,(85+$m),     'Amplitude modulation by Ramp '.($lfo+1));
    StdSlider(   \$subframe, \$PData[(39+$n)],       0,  63,$sp, 1,(83+$m),     'Retrigger Point');
    my @TrgMod_label=('off', 'single', 'multi', 'pedal 2');
    OptSelect(   \$subframe, \$PData[(36+$n)],  \@TrgMod_label,    (86+$m),  7, 'Trigger Mode:');
}

sub ModMatrix_Frame {
    my $subframe=$ModMatrix_frame->Frame(%Frame_defaults
    )->pack(-fill=>'both', -expand=>1, -anchor=>'n');

    $subframe->Label(%TitleLbl_defaults, -text=>'Source' )           ->grid(-row=>0, -column=>0, -columnspan=>2, -sticky=>'ew');
    $subframe->Label(%TitleLbl_defaults, -text=>'Modulation Amount' )->grid(-row=>0, -column=>2, -columnspan=>2, -sticky=>'ew');
    $subframe->Label(%TitleLbl_defaults, -text=>'Destination' )      ->grid(-row=>0, -column=>4, -columnspan=>2, -sticky=>'ew');

    for (my $a=0; $a<=9; $a++) {
        my $n=($a*3);

        %GridConf=(-row=>($a+1), -column=>0, -sticky=>'ew', -padx=>6, -pady=>6);
        PullDwnMenu( \$subframe, \$PData[(104+$n)],  \@mod_sources, ($a+100), 20, "$a) ");

        %GridConf=(-row=>($a+1), -column=>2, -sticky=>'ew', -padx=>6, -pady=>6);
        StdSlider(   \$subframe, \$PData[(105+$n)], -63,  63,$sn, 1,($a+100),     '');

        %GridConf=(-row=>($a+1), -column=>4, -sticky=>'ew', -padx=>6, -pady=>6);
        PullDwnMenu( \$subframe, \$PData[(106+$n)],  \@mod_dest,    ($a+100), 20, '');
    }
    %GridConf=();
}


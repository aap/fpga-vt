This is a simple terminal for the Terasic Cyclone V GX Starter Kit.

It outputs 800x600@60hz on the HDMI port,
reads input from a PS/2 keyboard (GPIO28 = CLK, GPIO29 = DATA),
sends and receives characters over the USB UART,
and is generally working roughly like a VT52.
I haven't implemented all control characters yet and actually
I'm also using a VT100 font for some reason.
In the future it would be nice to execute the VT52 microcode
or actually implement a full VT100 as well.

I started from [this](https://github.com/nhasbun/de10nano_vgaHdmi_chip)
code and the HDMI bits of it are still unmodified.

You can find a video of it in action [here](https://toobnix.org/w/smqLBfgrgirGarrF6JFvmU).


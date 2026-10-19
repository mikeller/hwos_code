/////////////////////////////////////////////////////////////////////////////
//
// compass_calib.c                                    next generation V3.09.4
//
// Calibrate hard-iron for magnetic compass measurements.
// Copyright (c) 2012-2019, JD Gascuel, heinrichs weikamp gmbh, all rights reserved.
//
//////////////////////////////////////////////////////////////////////////////

//  2015-05-22  [jDG] Make a smaller calibration code (15.6 --> 6.7 KB).
//  2019-05-14  [rl]  make smaller again

#include "configuration.inc"
#include "compass.h"


#ifdef _compass


//////////////////////////////////////////////////////////////////////////////
//
// Put compass data into bank 13 (stack) and bank 9 (variables)
//
#ifndef UNIX
#	pragma udata overlay bank13=0xd00
	static char C_STACK[256];				// overlay C-code data stack here
#	define C_STACK_ADDR C_STACK
#	define RESET_C_STACK			\
		_asm						\
			LFSR	1,C_STACK_ADDR	\
			LFSR	2,C_STACK_ADDR	\
		_endasm
#	pragma udata bank9b = 0x980
#	pragma code compass_cal
#	define PARAMETER	static
#	define OVERLAY		overlay
#else
#	define RESET_C_STACK
#	define PARAMETER
#	define OVERLAY
#endif


//////////////////////////////////////////////////////////////////////////////

static unsigned short int compass_N;

static float Su, Sv, Sw;					//						first  order moments
static float Suu, Svv, Sww, Suv, Suw, Svw;	//						second order moments
static float Saa;							// Suu  + Svv  + Sww
static float Saau;							// Suuu + Svvu + Swwu	third  order moment
static float Saav;							// Suuv + Svvv + Swwv	third  order moment
static float Saaw;							// Suuw + Svvw + Swww	third  order moment

static float yu, yv, yw;					// temp solution vector
static float uc, vc, wc;					// temp sphere's center

static float yh,uh,S0,S1,S2,S3;				// transfer vars for compass_solve_helper()

//////////////////////////////////////////////////////////////////////////////

void compass_reset_calibration()
{
	RESET_C_STACK;

	compass_N                                   = 0;
	Su           = Sv           = Sw            = 0.0;
	Suu          = Svv          = Sww           = 0.0;
	Suv          = Suw          = Svw           = 0.0;
	Saau         = Saav         = Saaw          = 0.0;
	compass_CX_f = compass_CY_f = compass_CZ_f  = 0;
}

//////////////////////////////////////////////////////////////////////////////

void compass_add_calibration()
{
	RESET_C_STACK;

	// get filtered/calibrated magnetic direction
	yu = (compass_DX_f - compass_CX_f) / 32768.0f;
	yv = (compass_DY_f - compass_CY_f) / 32768.0f;
	yw = (compass_DZ_f - compass_CZ_f) / 32768.0f;

	// add to all moments
	compass_N++;

	Su   += yu;
	Sv   += yv;
	Sw   += yw;

	Suu  += yu*yu;
	Suv  += yu*yv;
	Suw  += yu*yw;
	Svv  += yv*yv;
	Svw  += yv*yw;
	Sww  += yw*yw;

	Saa   = yu*yu + yv*yv + yw*yw;

	Saau += yu * Saa;
	Saav += yv * Saa;
	Saaw += yw * Saa;
}

//////////////////////////////////////////////////////////////////////////////

static float compass_discriminent(PARAMETER char column)
{
	// basic symmetric matrix
	OVERLAY float a = Suu, d = Suv, g = Suw;
	OVERLAY float b = Suv, e = Svv, h = Svw;
	OVERLAY float c = Suw, f = Svw, i = Sww;
	OVERLAY float result;

	// substitute a column, if asked to
	if( column==1 ) { a = yu; b = yv; c = yw; }
	if( column==2 ) { d = yu; e = yv; f = yw; }
	if( column==3 ) { g = yu; h = yv; i = yw; }

	// do the math in a couple of single terms to reduce
	// the amount of required ".tmpdata" memory
	result  = a * (e * i - f * h);
	result -= b * (d * i - f * g);
	result += c * (d * h - e * g);

	return result;
}

//////////////////////////////////////////////////////////////////////////////

static void compass_solve_helper(void)
{
	// computes:
	//
	// yh = S0 - Saa*uh - compass_dotc(Su*uh + 2*S1, Sv*uh + 2*S2, Sw*uh + 2*S3);
	//
	// with compass_dotc(u,v,w) = u*uc + v*vc + w*wc the equation becomes:
	//
	// yh = S0 - Saa*uh - ( (Su*uh + 2*S1)*uc + (Sv*uh + 2*S2)*vc + (Sw*uh + 2*S3)*wc )
	//
	// this equation is now split into several single terms
	// to reduce the amount of required ".tmpdata" memory:

	yh  = S0;
	yh -= Saa*uh;
	yh -= (Su*uh + 2*S1) * uc;
	yh -= (Sv*uh + 2*S2) * vc;
	yh -= (Sw*uh + 2*S3) * wc;

	return;
}

//////////////////////////////////////////////////////////////////////////////

void compass_solve_calibration()
{
	OVERLAY float delta;

	RESET_C_STACK;

	//---- Compute center of measured magnetic directions --------------------
	uc = Su/compass_N;
	vc = Sv/compass_N;
	wc = Sw/compass_N;

	//---- Normalize partial sums --------------------------------------------
	//
	// We measured the (u, v, w) values, and need the centered (x, y, z) ones
	// around the sphere center's (uc, vc, wc) as:
	// uc = Su / N;  The mean value
	// x  = u - uc;  The difference to the mean.
	//
	// So:
	// x**2 = (u - uc)**2 = u**2 - 2u*uc + uc**2
	//
	// We need the Sxx sum of 2nd orders:
	// Sxx = Suu - 2 uc Su + N*uc*(Su/N) = Suu - uc Su
	Suu -= Su*uc;
	Svv -= Sv*vc;
	Sww -= Sw*wc;

	// (u - uc)(v - vc) = uv - u vc - v uc + uc vc
	// Sxy = Suv - Su vc -   Sv uc + N uc vc
	//     = Suv - Su vc - N vc uc + N uc vc
	//     = Suv - Su vc
	Suv -= Su*vc;
	Suw -= Su*wc;
	Svw -= Sv*wc;

	// (u + um)**3 = u**3 + 3 u**2 um + 3 u um**2 + um**3
	// Sxxx = Suuu + 3 um Suu + 3 um**2 Su + N.um**3
	// Su   = 0, um = Sx/N:
	// Suuu = Sxxx - 3 Sx*Suu/N - N.(Sx/N)**3
	//      = Sxxx - 3 Sx*Suu/N - Sx**3/N**2

	// (u + um)**2 (v + vm) = (u**2 + 2 u um + um**2)(v + vm)
	// Sxxy = Suuv + vm Suu + 2 um (Suv + vm Su) + um**2 (Sv + N.vm)
	//
	// Su   = 0, Sv = 0, vm = Sy/N:
	// Sxxy = Suuv + vm Suu + 2 um Suv + N um**2 vm
	//
	// Suuv = Sxxy - (Sy/N) Suu - 2 (Sx/N) Suv - (Sx/N)**2 Sy
	//      = Sxxy - Suu*Sy/N - 2 Suv*Sx/N - Sx*Sx*Sy/N/N
	//      = Sxxy - (Suu + Sx*Sx/N)*Sy/N - 2 Suv*Sx/N

	Saa = Suu + Svv + Sww;

	// compute yu = Saau - Saa*uc - compass_dotc(Su*uc + 2*Suu, Sv*uc + 2*Suv, Sw*uc + 2*Suw);
	uh = uc; S0 = Saau; S1 = Suu; S2 = Suv; S3 = Suw;
	compass_solve_helper();
	yu = yh;

	// compute yv = Saav - Saa*vc - compass_dotc(Su*vc + 2*Suv, Sv*vc + 2*Svv, Sw*vc + 2*Svw);
	uh = vc; S0 = Saav; S1 = Suv; S2 = Svv; S3 = Svw;
	compass_solve_helper();
	yv = yh;

	// compute yw = Saaw - Saa*wc - compass_dotc(Su*wc + 2*Suw, Sv*wc + 2*Svw, Sw*wc + 2*Sww);
	uh = wc; S0 = Saaw; S1 = Suw; S2 = Svw; S3 = Sww;
	compass_solve_helper();
	yw = yh;


	//---- Solve the system --------------------------------------------------
	// uc Suu + vc Suv + wc Suw = (Suuu + Svvu + Swwu) / 2
	// uc Suv + vc Svv + wc Svw = (Suuv + Svvv + Swwv) / 2
	// uc Suw + vc Svw + wc Sww = (Suuw + Svvw + Swww) / 2
	//
	// Note this is symmetric, with a positive diagonal, hence discriminant is always not null

	delta = 0.5f / compass_discriminent(0);

	// computed new center, with offset values:
	uc += compass_discriminent(1) * delta;
	vc += compass_discriminent(2) * delta;
	wc += compass_discriminent(3) * delta;

	// add correction due to already applied calibration:
	compass_CX_f += (short)(32768 * uc);
	compass_CY_f += (short)(32768 * vc);
	compass_CZ_f += (short)(32768 * wc);
}

#endif	// _compass

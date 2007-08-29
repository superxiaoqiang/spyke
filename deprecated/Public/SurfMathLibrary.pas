unit SurfMathLibrary;

interface

uses Windows, SurfPublicTypes{for TWaveform declaration};

const
//  np = 32 {SURF_MAX_WAVEFORM_PTS };

  piBy2 = 2*pi;
  piBy4 = 4*pi;

  CRCTable :  array [0..255] of DWord =
  ($00000000, $77073096, $EE0E612C, $990951BA,
   $076DC419, $706AF48F, $E963A535, $9E6495A3,
   $0EDB8832, $79DCB8A4, $E0D5E91E, $97D2D988,
   $09B64C2B, $7EB17CBD, $E7B82D07, $90BF1D91,
   $1DB71064, $6AB020F2, $F3B97148, $84BE41DE,
   $1ADAD47D, $6DDDE4EB, $F4D4B551, $83D385C7,
   $136C9856, $646BA8C0, $FD62F97A, $8A65C9EC,
   $14015C4F, $63066CD9, $FA0F3D63, $8D080DF5,
   $3B6E20C8, $4C69105E, $D56041E4, $A2677172,
   $3C03E4D1, $4B04D447, $D20D85FD, $A50AB56B,
   $35B5A8FA, $42B2986C, $DBBBC9D6, $ACBCF940,
   $32D86CE3, $45DF5C75, $DCD60DCF, $ABD13D59,
   $26D930AC, $51DE003A, $C8D75180, $BFD06116,
   $21B4F4B5, $56B3C423, $CFBA9599, $B8BDA50F,
   $2802B89E, $5F058808, $C60CD9B2, $B10BE924,
   $2F6F7C87, $58684C11, $C1611DAB, $B6662D3D,

   $76DC4190, $01DB7106, $98D220BC, $EFD5102A,
   $71B18589, $06B6B51F, $9FBFE4A5, $E8B8D433,
   $7807C9A2, $0F00F934, $9609A88E, $E10E9818,
   $7F6A0DBB, $086D3D2D, $91646C97, $E6635C01,
   $6B6B51F4, $1C6C6162, $856530D8, $F262004E,
   $6C0695ED, $1B01A57B, $8208F4C1, $F50FC457,
   $65B0D9C6, $12B7E950, $8BBEB8EA, $FCB9887C,
   $62DD1DDF, $15DA2D49, $8CD37CF3, $FBD44C65,
   $4DB26158, $3AB551CE, $A3BC0074, $D4BB30E2,
   $4ADFA541, $3DD895D7, $A4D1C46D, $D3D6F4FB,
   $4369E96A, $346ED9FC, $AD678846, $DA60B8D0,
   $44042D73, $33031DE5, $AA0A4C5F, $DD0D7CC9,
   $5005713C, $270241AA, $BE0B1010, $C90C2086,
   $5768B525, $206F85B3, $B966D409, $CE61E49F,
   $5EDEF90E, $29D9C998, $B0D09822, $C7D7A8B4,
   $59B33D17, $2EB40D81, $B7BD5C3B, $C0BA6CAD,

   $EDB88320, $9ABFB3B6, $03B6E20C, $74B1D29A,
   $EAD54739, $9DD277AF, $04DB2615, $73DC1683,
   $E3630B12, $94643B84, $0D6D6A3E, $7A6A5AA8,
   $E40ECF0B, $9309FF9D, $0A00AE27, $7D079EB1,
   $F00F9344, $8708A3D2, $1E01F268, $6906C2FE,
   $F762575D, $806567CB, $196C3671, $6E6B06E7,
   $FED41B76, $89D32BE0, $10DA7A5A, $67DD4ACC,
   $F9B9DF6F, $8EBEEFF9, $17B7BE43, $60B08ED5,
   $D6D6A3E8, $A1D1937E, $38D8C2C4, $4FDFF252,
   $D1BB67F1, $A6BC5767, $3FB506DD, $48B2364B,
   $D80D2BDA, $AF0A1B4C, $36034AF6, $41047A60,
   $DF60EFC3, $A867DF55, $316E8EEF, $4669BE79,
   $CB61B38C, $BC66831A, $256FD2A0, $5268E236,
   $CC0C7795, $BB0B4703, $220216B9, $5505262F,
   $C5BA3BBE, $B2BD0B28, $2BB45A92, $5CB36A04,
   $C2D7FFA7, $B5D0CF31, $2CD99E8B, $5BDEAE1D,

   $9B64C2B0, $EC63F226, $756AA39C, $026D930A,
   $9C0906A9, $EB0E363F, $72076785, $05005713,
   $95BF4A82, $E2B87A14, $7BB12BAE, $0CB61B38,
   $92D28E9B, $E5D5BE0D, $7CDCEFB7, $0BDBDF21,
   $86D3D2D4, $F1D4E242, $68DDB3F8, $1FDA836E,
   $81BE16CD, $F6B9265B, $6FB077E1, $18B74777,
   $88085AE6, $FF0F6A70, $66063BCA, $11010B5C,
   $8F659EFF, $F862AE69, $616BFFD3, $166CCF45,
   $A00AE278, $D70DD2EE, $4E048354, $3903B3C2,
   $A7672661, $D06016F7, $4969474D, $3E6E77DB,
   $AED16A4A, $D9D65ADC, $40DF0B66, $37D83BF0,
   $A9BCAE53, $DEBB9EC5, $47B2CF7F, $30B5FFE9,
   $BDBDF21C, $CABAC28A, $53B39330, $24B4A3A6,
   $BAD03605, $CDD70693, $54DE5729, $23D967BF,
   $B3667A2E, $C4614AB8, $5D681B02, $2A6F2B94,
   $B40BBE37, $C30C8EA1, $5A05DF1B, $2D02EF8D);

type  TReal32        = single;
      TReal64        = double;
      TSplineArray   = array of TReal32; //nb: open array
      TReal32Array   = array of TReal32;
      TReal64Array   = array of TReal64;

      LPUSHRT = ^smallint;
      LPREAL32 = ^TReal32;
      TInteger8 = Int64;     // Delphi 5

      TRunMeanInt = record
        NewData : array of integer;
        NumVals : integer;
      end;

      TComplexForm   = (cfPolar, cfRectangular);
      TComplex       = record
      case form : TComplexForm of
        cfRectangular:  (x,y    :  TReal32);  // z = x + i*y
        cfPolar      :  (r,theta:  TReal32);  // z = r*CIS(theta)
      end;      // where CIS(theta) = COS(theta) + i*SIN(theta)
               //       theta = -PI..PI (in canonical form)

      TSortOrder = (ssAscending, ssDescending);
      TIntArray = array of integer;

{Cubic spline interpolation}
{procedure InitSplineX;}
procedure Spline (const x : TSplineArray;
                  const y : TSplineArray;
                   var y2 : TSplineArray);
procedure Splint (var x : array of TReal32;
            const y, y2 : array of TReal32;
                     xa : TReal32;
       var{const?} yint : TReal32);

{Convolution, interpolation}
(*procedure MakeSincKernel(var Kernel       : TReal32Array;
                         var InterpFactor : integer;
                             ShiftSamples : TReal32 = 0;
                             FilterCutoff : TReal32 = 0.5;
                       ApplyHammingWindow : boolean = True);*)

procedure MakeSincKernel(var   Kernel      : TReal32Array;
                              KernelLength : integer;
                              ShiftSamples : TReal32 = 0;
                              FilterCutoff : TReal32 = 0.5;
                        ApplyHammingWindow : boolean = True);

procedure Convolve(const h : array of TReal32; var x, y : array of TReal32);{SmallInt);}
{procedure Upsample(factor : integer; const kernel : array of TReal32;
                   var input, output : array of Smallint);}
procedure Upsample(factor : integer; const kernel : array of TReal32Array;
                   const input : TWaveform; var output : LPUSHRT{PWaveform});

{FFT}
procedure FFT (var Data : array of TReal32;
                     nn : integer;
                  isign : shortint);
procedure RealFFT (var Data : array of TReal32;
                          n : integer;
                      isign : shortint);
{procedure BuffFFT(const Data      : array of single;
                        FFTOUT    : array of TReal32;
                                n : integer;
                            isign : shortint);
{procedure TwoFFT (const Data1, Data2 : array of TReal32;
                      var fft1, fft2 : array of TComplex;
                                   n : integer);}
procedure MUXFFT (Data : array of TReal32;
        var fft1, fft2 : array of TComplex;
                     n : integer);

procedure XCorr(const SeriesA, SeriesB: array of Word;
                var r : array of TReal32);{: TReal32Array;}

{Overloaded native Delphi functions}
function MaxShrtValue (const Data: array of SmallInt): SmallInt;
function MinShrtValue (const Data: array of SmallInt): SmallInt;
function MaxCardValue (const Data: array of cardinal): cardinal;

function SumOfShrtSquares (const Data: array of SmallInt): Extended;
function MeanShrt (const Data: array of SmallInt): Extended;

{Running statistics}
function RunningMeanInt (var NewMean : TRunMeanInt): Double;

{Complex math}
function CSet (const a,b: TReal32; const f: TComplexForm = cfRectangular): TComplex;
function Conjg (c: TComplex) : TComplex;
function CAdd (const a,b:  TComplex) : TComplex;
function CSub(const a,b:  TComplex):  TComplex;
function CMult(const a,b:  TComplex):  TComplex;
function CMag(const a: TComplex): TReal32;
function CPhi(const a: TComplex): TReal32;
function MaxCmplxReal(const Data: array of TComplex): TReal32;
function MaxCmplxRealPos(const Data: array of TComplex): integer;
function MaxMagPosn(const Data: array of TComplex): integer;

{DTx ADC support}
procedure Input2Volts(const InputBuffer : TWaveform{array of Word};
                      const Resolution  : word;
                          const ExtGain : TReal32;
                       var OutputBuffer : LPREAL32;
                       //var OutputBuffer : TReal32Array{open dynarr};
                       const ADCVRange  : TReal32 = 20{default});
{32bit CRC}
procedure CalcCRC32     (p: pointer; ByteCount: DWord; var CRCvalue: DWord);
procedure CalcFileCRC32 (FromName: string; var CRCvalue: DWord;
                         var TotalBytes:  TInteger8;
                         var error:  Word);

{var splinex,spliney,spline2ndderiv : SplineArrayNP;}

{Sorting routines}
procedure ShellSort (var SortElements : array of integer;
                                Order : TSortOrder = ssAscending;
                     const IndexOrder : TIntArray = nil);

procedure ShellSort64 (var SortElements : array of int64; //64 bit version
                                  Order : TSortOrder = ssAscending;
                       const IndexOrder : TIntArray = nil);
{Current Source Density}
procedure CSD(const Waveforms : TWaveform; ndeltaY, NChans : integer;
              var CSDOut : array of TReal32);

implementation

uses Dialogs, SysUtils, Classes, Math;// for TMemoryStream in CRC32

{------------------------------------------------------------------------------}
{procedure InitSplineX; //initialise for timeseries spline
var n : integer;
begin
  for n := 1 to np do splinex[n] := n;
end;
}
{------------------------------------------------------------------------------}
procedure Spline (const x : TSplineArray;
                  const y : TSplineArray;
                   var y2 : TSplineArray);

{Given arrays x[1..n] and y[1..n] containing a tabulated function, i.e.
yi=f(xi) with x1<x2<x3<...xn, and given values yp1 and ypn for the first
derivatives of the interpolating function at points 1 and n, this routine
returns an array y2[1..n] that contains the second derivatives of the
interpolating function at the tabulated points xi.  If yp1 and/or yp2
are equal to 1x10^30 or larger, the routine is signalled to set the
corresponding boundary condition for a natural spline, with zero second
derivative on that boundary.}

{ 4.4.03: modified to Open array version }

var i, k           : integer;
    p, qn, sig, un : TReal32;
    u              : TSplineArray;
    yp1, ypn       : TReal32;

begin
  yp1:= 0.99E30+1;
  ypn:= 0.99E30+1;

  {New}Setlength(u, Length(x));
  if yp1>0.99E30 then
  begin
    y2[0]:= 0.0;
    u[0]:= 0.0;
  end else
  begin
    y2[0]:= -0.5;
    u[0]:= (3.0/(x[1]-x[0]))*((y[1]-y[0])/(x[1]-x[0])-yp1);
  end;

  for i:= 1 to High(x) do
  begin
    sig:=(x[i]-x[i-1])/(x[i+1]-x[i-1]);
    p:=sig*y2[i-1]+2.0;
    y2[i]:=(sig-1.0)/p;
    u[i]:=(y[i+1]-y[i])/(x[i+1]-x[i])-(y[i]-y[i-1])/(x[i]-x[i-1]);
    u[i]:=(6.0*u[i]/(x[i+1]-x[i-1])-sig*u[i-1])/p;
  end;

  if ypn>0.99E30 then
  begin
    qn:=0.0;
    un:=0.0;
  end else
  begin
    qn:=0.5;
    un:=(3.0/(x[High{?}(x)]-x[High{?}(x)-1]))*(ypn-
        (y[High(y)]-y[High(y)-1])/(x[High(x)]-x[High(x)-1]));
  end;

  y2[High(y2)]:=(un*u[High(y2)-1])/(qn*y2[High(y2)-1]+1.0);

  for k:=High(y2) downto 1 do
    y2[k]:=y2[k]*y2[k+1]+u[k];

end;

{------------------------------------------------------------------------------}
procedure Splint (var x : array of TReal32;
            const y, y2 : array of TReal32;
                     xa : TReal32;
       var{const?} yint : TReal32);

{Given the arrays x[1..n] and y[1..n] which tabulate a function (with x's
in order), and given the array y2[1..n], which is the output from SPLINE
above, and given a value of 'x', this routine returns a cubic spline
interpolated value 'y'.}

var klo,khi,k : integer;
    h,b,a     : TReal32;

begin
  klo:= Low(x);
  khi:= High(x);
  while khi-klo > 1 do
  begin
    k:=(khi+klo) div 2;
    if x[k] > xa then khi:=k
      else klo:=k;
  end;

  h:=x[khi]-x[klo];
  if h=0.0 then halt;//Showmessage('Pause in routine splint; Bad x input');

  a:=(x[khi]-xa)/h;
  b:=(xa-x[klo])/h;
  yint:=a*y[klo]+b*y[khi]+((a*a*a-a)*y2[klo]+(b*b*b-b)*y2[khi])*(h*h)/6;
end;


// START OF OLD (TEMPORARY)CODE
// TO BE ERASED WHEN ABOVE IS FUNCTIONAL
{------------------------------------------------------------------------------}
{procedure Spline (var splinex : SplineArrayNP;
                      y : SplineArrayNP;
                   npts : integer;
                 var y2 : SplineArrayNP);

{Given arrays x[1..n] and y[1..n] containing a tabulated function, i.e.
yi=f(xi) with x1<x2<x3<...xn, and given values yp1 and ypn for the first
derivatives of the interpolating function at points 1 and n, this routine
returns an array y2[1..n] that contains the second derivatives of the
interpolating function at the tabulated points xi.  If yp1 and/or yp2
are equal to 1x10^30 or larger, the routine is signalled to set the
corresponding boundary condition for a natural spline, with zero second
derivative on that boundary.}

{var i,k         : integer;
    p,qn,sig,un : TReal32;
    u           : ^SplineArrayNP;
    yp1,ypn     : TReal32;

begin
  yp1 := 0.99E30+1;
  ypn := 0.99E30+1;

  new(u);
  if yp1>0.99E30 then
  begin
    y2[1]:=0.0;
    u^[1]:=0.0;
  end else
  begin
    y2[1]:=-0.5;
    u^[1]:=(3.0/(splinex[2]-splinex[1]))*((y[2]-y[1])/(splinex[2]-splinex[1])-yp1);
  end;

  for i:=2 to npts-1 do
  begin
    sig:=(splinex[i]-splinex[i-1])/(splinex[i+1]-splinex[i-1]);
    p:=sig*y2[i-1]+2.0;
    y2[i]:=(sig-1.0)/p;
    u^[i]:=(y[i+1]-y[i])/(splinex[i+1]-splinex[i])-(y[i]-y[i-1])/(splinex[i]-splinex[i-1]);
    u^[i]:=(6.0*u^[i]/(splinex[i+1]-splinex[i-1])-sig*u^[i-1])/p;
  end;

  if ypn>0.99E30 then
  begin
    qn:=0.0;
    un:=0.0;
  end else
  begin
    qn:=0.5;
    un:=(3.0/(splinex[npts]-splinex[npts-1]))*(ypn-
        (y[npts]-y[npts-1])/(splinex[npts]-splinex[npts-1]));
  end;

  y2[npts]:=(un*u^[npts-1])/(qn*y2[npts-1]+1.0);

  for k:=npts-1 downto 1 do
    y2[k]:=y2[k]*y2[k+1]+u^[k];

  Dispose(u);
end;

{------------------------------------------------------------------------------}
{procedure Splint (var splinex : SplineArrayNP;
                      y,y2 : SplineArrayNP;
                      npts : integer;
                        xa : TReal32;
                  var yint : TReal32);

{Given the arrays x[1..n] and y[1..n] which tabulate a function (with x's
in order), and given the array y2[1..n], which is the output from SPLINE
above, and given a value of 'x', this routine returns a cubic spline
interpolated value 'y'.}

{var klo,khi,k : integer;
    h,b,a     : TReal32;

begin
  klo:=1;
  khi:=npts;
  while khi-klo > 1 do
  begin
    k:=(khi+klo) div 2;
    if splinex[k] > xa then khi:=k
      else klo:=k;
  end;

  h:=splinex[khi]-splinex[klo];
  if h=0.0 then halt;//Showmessage('Pause in routine splint; Bad x input');

  a:=(splinex[khi]-xa)/h;
  b:=(xa-splinex[klo])/h;
  yint:=a*y[klo]+b*y[khi]+((a*a*a-a)*y2[klo]+(b*b*b-b)*y2[khi])*(h*h)/6;
end;

// END OF OLD CODE

}
{------------------------------------------------------------------------------}
(*procedure MakeSincKernel(var Kernel       : TReal32Array;
                         var InterpFactor : integer;
                             ShiftSamples : TReal32{default = 0, no phase offset};
                             FilterCutoff : TReal32{default = 0.5, no filter};
                       ApplyHammingWindow : boolean{default = true, apply Blackman window});
var i, LUTLength  : integer;
  sigma, tZero, kTimescale, t : TReal32;
begin
  {range error checks}
  if (ShiftSamples > 1) or (ShiftSamples < -1) then
  begin
    Showmessage('Phase shift too large; sinc kernel not generated');
    Exit;
  end;
  if InterpFactor < 1 then InterpFactor:= 1;
  if (FilterCutoff < 0) or (FilterCutoff > 0.5) then FilterCutoff:= 0.5;
  LUTLength:= 6 * InterpFactor {-}+ 1; //pass numbits and make some relationship to quantization precision/zero crossings
  tZero:= (LUTlength - 1) * 0.5;
  //inc(LUTLength, Abs(Trunc(ShiftSamples)*InterpFactor{*2?}));
  try
    if Length(Kernel) <> LUTLength then SetLength(Kernel, LUTLength);
  except
    Showmessage('Unable to allocate memory for kernel; no sinc kernel generated');
    Kernel:= nil;
    Exit;
  end;
  kTimescale:= 1 / InterpFactor;
  {generate filter kernel}
  for i:= 0 to LUTLength -1 do
  begin
    t:= (i - tZero) * kTimescale - ShiftSamples;
    if t = 0 then Kernel[i]:= PiBy2*FilterCutoff{1}
      else Kernel[i]:= sin(PiBy2*FilterCutoff*t)/t;
    if ApplyHammingWindow then Kernel[i]:= Kernel[i] * (0.54 - 0.46 * cos(piBy2*i/(LUTLength-1)));
    {if ApplyBlackmanWindow then h[i]:= h[i] * (0.42 - 0.5 * cos(piBy2*i/(LUTLength-1))
                                     + 0.08 * cos(piBy4*i/(LUTLength-1)));}
  end;
  {normalise filter kernel (unity gain at DC)}
  sigma:= Kernel[0];
  for i:= 1 to High(Kernel) do sigma:= sigma + Kernel[i];
  sigma:= sigma * kTimescale;
  for i:= 0 to High(Kernel) do Kernel[i]:= Kernel[i]/sigma;
end;
*)
{------------------------------------------------------------------------------}
procedure MakeSincKernel(var  Kernel       : TReal32Array;
                              KernelLength : integer;
                              ShiftSamples : TReal32{default = 0, no phase offset};
                              FilterCutoff : TReal32{default = 0.5, no filter};
                        ApplyHammingWindow : boolean{default = true, apply Hamming window});
var i : integer;
    sigma, {ktimescale,} t, tCentre : TReal32;
begin
  {range error checks}
  if (ShiftSamples > 1) or (ShiftSamples < -1) then
  begin
    Showmessage('Phase shift too large; sinc kernel not generated');
    Exit;
  end;
  if (FilterCutoff < 0) or (FilterCutoff > 0.5) then FilterCutoff:= 0.5;
  tCentre:= (KernelLength - 1) / 2 ;
  try
    if Length(Kernel) <> KernelLength then SetLength(Kernel, KernelLength);
  except
    Showmessage('Unable to allocate memory for kernel; no sinc kernel generated');
    Kernel:= nil;
    Exit;
  end;
  {ktimescale:= 1/1.5interpfactor};
  {generate filter kernel}
  for i:= 0 to KernelLength - 1 do
  begin
    t:= (i - tCentre - ShiftSamples) {* ktimescale};
    if t = 0 then Kernel[i]:= PiBy2*FilterCutoff
      else Kernel[i]:= sin(PiBy2*FilterCutoff*t)/t;
    if ApplyHammingWindow then Kernel[i]:= Kernel[i] * (0.54 - 0.46 * cos(piBy2*{(}i {+ ShiftSamples)}/(KernelLength-1)));
    {if ApplyBlackmanWindow then h[i]:= h[i] * (0.42 - 0.5 * cos(piBy2*i/(LUTLength-1))
                                     + 0.08 * cos(piBy4*i/(LUTLength-1)));}
  end;
  {normalise filter kernel (unity gain at DC)}
  sigma:= Kernel[0];
  for i:= 1 to High(Kernel) do sigma:= sigma + Kernel[i];
  for i:= 0 to High(Kernel) do Kernel[i]:= Kernel[i]/sigma; //ktimescale
end;

{------------------------------------------------------------------------------}
procedure Convolve(const h : array of TReal32; var x, y : array of TReal32{SmallInt});
var i, j, lh, lx : integer;
begin
  lh:= Length(h);
  lx:= Length(x);
  {check array sizes compatible}
  if lh >= lx then
    Showmessage('Filter kernel too long for input array')
  else if Length(y) <> lx + lh then
    Showmessage('Output array wrong length')
  else {convolve the input signal x[] with the filter kernel y[]}
    for i:= High(h) to High(x) do
    begin
      y[i]:= 0;
      for j:= Low(h) to High(h) do
        y[i]:= {Round(}y[i] + x[i-j] * h[j];
    end{i};
end;

{------------------------------------------------------------------------------}
(*procedure Upsample(factor : integer; const kernel : array of TReal32;
                   var input, output : array of Smallint);
var i, j, k, oi, ii, KernelLength, InputLength : integer;
  total : TReal32;
begin //need to modify for open-array compatibility!
  {ensure array sizes compatible}
  KernelLength:= Length(kernel);
  InputLength:= Length(input);
  if Length(output) <> factor * (InputLength - KernelLength) then
    Showmessage('Array lengths incompatible') else
  begin {y[] = x[] * h[], with upsample}
    oi:= 0;
    for i:= 0 to InputLength - KernelLength - 1 do  //replace with High + 1?
    begin
      for j:= factor-1 downto 0 do
      begin
        k:= j;
        ii:= i;
        total:= 0;
        while k < KernelLength {- 1} do
        begin
          total:= total + input[ii] * kernel[k];
          inc(ii);
          inc(k, factor);
        end{k};
        output[oi]:= Round(total);
        inc(oi);
      end{j};
    end{i};
  end{convolution};
end;
*)
{------------------------------------------------------------------------------}
procedure Upsample(factor : integer; const kernel : array of TReal32Array;
                   const input : TWaveform; var output : LPUSHRT);
var i, j, k,{ ik, oi,} kernelLen : integer;
  total : TReal32;
begin
  kernelLen:= Length(kernel[0]);
  begin {y[] = x[] * h[], with upsample}
    //oi:= Low(output);
    for i:= Low(input) to High(input) - kernelLen do
      for j:= 0 to factor - 1 do
      begin
        total:= 0;
        for k:= 0 to kernelLen - 1  do
          total:= total + input[i+k] * kernel[j,k];
        output^:= Round(total);
        inc(output);
      end{j};
  end{upsample convolution};
end;

{------------------------------------------------------------------------------}
procedure FFT(var Data : array of TReal32;
                    nn : integer;
                 isign : shortint);
var i, istep, j, m, mmax, n : integer;
    tempi, tempr : TReal32;
    theta, wi, wpi, wpr, wr, wtemp : TReal64;
begin
  n:= 2*nn;  //perform bit reversal routine here
  j:= 1;
  i:= 1;
  while i < n do
  begin
    if j > i then
    begin
      tempr:= data[j];
      tempi:= data[j+1];
      data[j]:= data[i];
      data[j+1]:= data[i+1];
      data[i]:= tempr;
      data[i+1]:= tempi;
    end;
    m:= n div 2;
    while (m >= 2) and (j > m) do
    begin
      j:= j - m;
      m:= m div 2;
    end;
    j:= j + m;
    inc (i,2);
  end;
  mmax:= 2; // Danielson-Lanczos section of routine begins here
  while n > mmax do
  begin
    istep:= 2 * mmax;
    theta:= 6.28318530717959 / (isign * mmax);
    wpr:= -2.0 * sqr(sin(0.5 * theta));
    wpi:= sin (theta);
    wr:= 1.0;
    wi:= 0.0;
    m:= 1;
    while m < mmax do
    begin
      i:= m;
      while i < n do
      begin
        j:= i + mmax;
        tempr:= wr * data[j] - wi * data[j+1];
        tempi:= wr * data[j+1] + wi * data[j];
        data[j]:= data[i] - tempr;
        data[j+1]:= data[i+1] - tempi;
        data[i]:= data[i] + tempr;
        data[i+1]:= data[i+1] + tempi;
        inc (i, istep);
      end;
      wtemp:= wr;
      wr:= wr * wpr - wi * wpi + wr;
      wi:= wi * wpr + wtemp * wpi + wi;
      inc (m,2);
    end;
    mmax:= istep;
  end;
end;
{------------------------------------------------------------------------------}
procedure RealFFT(var Data : array of TReal32;
                         n : integer;
                     isign : shortint);
var i, i1, i2, i3, i4, n2p3 : integer;
  c1, c2, h1i, h1r, h2i, h2r, wis, wrs : TReal32;
  theta, wi, wpi, wpr, wr, wtemp : TReal64;
begin
  theta := pi / (n/2);
  c1 := 0.5;
  if isign = 1 then
  begin
    c2:= - 0.5;
    FFT(Data, n div 2, 1);
  end else
  begin
    c2:= 0.5;
    theta:= - theta;
  end;
  wpr:= -2.0 * sqr(sin(0.5 * theta));
  wpi:= sin (theta);
  wr:= 1.0 + wpr;
  wi:= wpi;
  n2p3:= n + 3;
  for i:= 2 to (n div 4) do
  begin
    i1:= 2 * i -1;
    i2:= i1 + 1;
    i3:= n2p3 - i2;
    i4:= i3 + 1;
    wrs:= wr;
    wis:= wi;
    h1r:= c1 * (data[i1] + data [i3]);
    h1i:= c1 * (data[i2] - data [i4]);
    h2r:= -c2 * (data[i2] + data [i4]);
    h2i:= c2 * (data[i1] - data [i3]);
    data[i1]:= h1r + wrs * h2r - wis * h2i;
    data[i2]:= h1i + wrs * h2i + wis * h2r;
    data[i3]:= h1r - wrs * h2r + wis * h2i;
    data[i4]:= -h1i + wrs * h2i + wis * h2r;
    wtemp := wr;
    wr:= wr * wpr - wi * wpi + wr;
    wi:= wi * wpr + wtemp * wpi + wi;
  end{i};
  if isign = 1 then
  begin
    h1r:= data[1];
    data[1]:= h1r + data[2];
    data[2]:= h1r - data[2];
  end else
  begin
    h1r:= data[1];
    data[1]:= c1 * (h1r + Data [2]);
    data[2]:= c1 * (h1r - Data [2]);
    FFT (Data, n div 2, -1);
  end;
end;

{------------------------------------------------------------------------------}
{procedure TwoFFT(const Data1, Data2 : array of TReal32;
                     var fft1, fft2 : array of TComplex;
                                  n : integer);
var j, n2 : integer;
  h1, h2, c1, c2 : TComplex;
begin
  c1:= CSet(0.0, 0.5);
  c2:= CSet(0.0, -0.5);
  for j:= 1 to n do
    fft1[j]:= CSet(Data1[j], Data2[j]);
  FFT(fft1, n, 1);
  fft2[1]:= CSet(fft1[1].y, 0.0);
  fft1[1]:= CSet(fft1[1].x, 0.0);
  n2:= n + 2;
  for j:= 2 to n div 2 + 1 do
  begin
    h1:= c1 * (fft1[j] + Conjg(fft1[n2-j]));
    h2:= c2 * (fft1[j] - Conjg(fft1[n2-j]));
    fft1[j] := h1;
    fft1[n2-j]:= Conjg(h1);
    fft2[j] := h2;
    fft2[n2-j]:= Conjg(h2);
  end;
end;
}
{------------------------------------------------------------------------------}
procedure MuxFFT (Data : array of TReal32;
        var fft1, fft2 : array of TComplex;
                     n : integer);
var j, j2, n2 : integer;
  h1, h2, c1, c2 : TComplex;
begin
  c1:= CSet(0.5, 0.0);
  c2:= CSet(0.0, -0.5);
  FFT(Data, n, 1); //transform the muxed real data
  {for j:= 1 to n do
  begin
    fft1[j].x:= Data[j];
    fft2[j].y:= Data[j+1];
  end;}
  j:=1;
  j2:=1;
  while j < n  do
  begin
    fft1[j].x:= Data[j2];
    fft1[j].y:= Data[j2+1];{fft1[j]:= CSet(data[j], data[j+1]);} //pack muxed FFT data into
    inc (j);
    inc (j2, 2); //one complex array, FFT1
  end;
  fft2[1]:= CSet(fft1[1].y, 0.0);
  fft1[1]:= CSet(fft1[1].x, 0.0);
  n2:= n + 2;
  j:= 2;
  while j < (n div 2 + 1) do
  {for j:= 2 to (n div 2 + 1) do}
  begin
    h1:= CMult(c1, CAdd(fft1[j], Conjg(fft1[n2-j]))); //assumes complex numbers
    h2:= CMult(c2, CSub(fft1[j], Conjg(fft1[n2-j]))); //are in rectangular form!
    fft1[j] := h1;
    fft1[n2-j]:= Conjg(h1);
    fft2[j] := h2;
    fft2[n2-j]:= Conjg(h2);
    inc(j);
  end;
end;

{------------------------------------------------------------------------------}
procedure XCorr(const SeriesA, SeriesB: array of Word;
                  var r : array of TReal32);    //needs basic error checking
var i, j, n, delay : integer;                                          //needs to be optimised with asm!
  MeanA, MeanB,  sA, sB, sAB, Denom: TReal64;                          //current Math unit wrong type!
begin                                                                  //for sum, mean, etc...
  {calculate series means}
  n := High(SeriesA) + 1; //as open array always zero based
  MeanA:= SeriesA[0];
  MeanB:= SeriesB[0];
  for i:= 1 to n - 1 do
  begin
    MeanA:= MeanA + SeriesA[i];
    MeanB:= MeanB + SeriesB[i];
  end;
  MeanA:= MeanA / n;
  MeanB:= MeanB / n;
  {calculate the denominator}
  sA:= 0;
  sB:= 0;
  for i:= 0 to n - 1 do
  begin
    sA:= sA + (SeriesA[i] - MeanA) * (SeriesA[i] - MeanA);
    sB:= sB + (SeriesB[i] - MeanB) * (SeriesB[i] - MeanB);
  end;
  Denom:= Sqrt(sA * sB);
  {calculate the correlation series}
  for j:= -(n div 2) to (n div 2) do
  begin
    sAB:= 0;
    for i:= 0 to n - 1 do
    begin
      delay:= i + j;
      if (delay < 0) or (delay >= n) then
        continue;
      sAB:= sAB + ((SeriesA[i] - MeanA) * (SeriesB[delay] - MeanB));
    end;
    r[j+8]:= sAB / Denom;
  end;
end;

{------------------------------------------------------------------------------}
function MaxShrtValue(const Data: array of SmallInt): SmallInt;
var
  i : integer;
begin
  Result := Data[Low(Data)];
  for i := Low(Data) + 1 to High(Data) do
    if Result < Data[i] then
      Result := Data[i];
end;

{------------------------------------------------------------------------------}
function MinShrtValue(const Data: array of SmallInt): SmallInt;
var
  i: Integer;
begin
  Result:= Data[Low(Data)];
  for i:= Low(Data) + 1 to High(Data) do
    if Result > Data[i] then
      Result := Data[i];
end;

{------------------------------------------------------------------------------}
function MaxCardValue(const Data: array of cardinal): cardinal;
var
  i : Integer;
begin
  Result:= Data[Low(Data)];
  for i:= Low(Data) + 1 to High(Data) do
    if Result < Data[i] then
      Result:= Data[i];
end;

{------------------------------------------------------------------------------}
function SumOfShrtSquares(const Data: array of SmallInt): Extended; //adapted from Delphi Math lib.
var
  I: Integer;
begin
  Result := 0.0;
  for I := Low(Data) to High(Data) do
    Result := Result + (Data[I]*Data[I]);
end;

{------------------------------------------------------------------------------}
function MeanShrt(const Data: array of SmallInt): Extended;
var i: Integer;
begin
  Result:= 0.0;
  for i:= Low(Data) to High(Data) do
    Result := Result + Data[i];
  Result:= Result / High(Data);
end;

{------------------------------------------------------------------------------}
function RunningMeanInt(var NewMean : TRunMeanInt): Double;
begin {unfinished, do not use yet}
  with NewMean do
  begin
    Result:= SumInt(NewData);
    inc(NumVals, High(NewData));
    Result:= Result / NumVals;
  end;
end;

{------------------------------------------------------------------------------}
function CSet(const a,b: TReal32; const f: TComplexForm = cfRectangular): TComplex;
begin
  Result.form := f;
  case f of
    cfRectangular:
    begin
      Result.x := a;
      Result.y := b;
    end;

    cfPolar:
    begin
      Result.r := a;
      Result.theta := b;
    end;
  end;
end;

{------------------------------------------------------------------------------}
function Conjg(c: TComplex) : TComplex; //implement as procedure with var?
begin
  Result.form := cfRectangular;
  {case c.form of
    cfPolar:
     begin
       RESULT.r := a.r;
       RESULT.theta := FixAngle(-a.theta)
     end;

    cfRectangular:
    begin    }
      Result.x := c.x;
      Result.y := -c.y;
    {end;
  end;}
end;

{------------------------------------------------------------------------------}
function CAdd(Const a,b:  TComplex) : TComplex;
begin
  Result.form := cfRectangular;
  Result.x:= a.x + b.x;
  Result.y:= a.y + b.y;
end;
{var
  aTemp:  TComplex;
  bTemp:  TComplex;
begin
  // Can't add values if in cfPolar form.
  // Convert to cfRectangular if necessary.
  aTemp := CConvert(a, cfRectangular);
  bTemp := CConvert(b, cfRectangular);
  Result.form := cfRectangular;
  Result.x := aTemp.x + bTemp.x;   // real part
  Result.y := aTemp.y + bTemp.y;   // imaginary part
end;}

{------------------------------------------------------------------------------}
function CSub(Const a,b:  TComplex):  TComplex;
begin
  Result.form := cfRectangular;
  Result.x:= a.x - b.x;
  Result.y:= a.y - b.y;
end;
{var
  aTemp:  TComplex;
  bTemp:  TComplex;
begin
  aTemp := CConvert (a,cfRectangular);
  bTemp := CConvert (b,cfRectangular);
  Result.form := cfRectangular;
  Result.x := aTemp.x - bTemp.x;   // real part
  Result.y := aTemp.y - bTemp.y;   // imaginary part
end;}

{------------------------------------------------------------------------------}
function CMult(const a,b:  TComplex):  TComplex;
begin
  Result.form := cfRectangular;
  Result.x := a.x*b.x - a.y*b.y;
  Result.y := a.x*b.y + a.y*b.x;
end;
{var
  bTemp:  TComplex;
begin
  bTemp := CConvert(b, a.form);  // arbitrarily convert one to type of other
  Result.form := a.form;         // (ie. no conversion if both are the same)
  case a.form of
    cfPolar:
    begin
      Result.r := a.r * bTemp.r;
      Result.theta := FixAngle(a.theta + bTemp.theta);
    end;

    cfRectangular:
    begin
      Result.x := a.x*bTemp.x - a.y*bTemp.y;
      Result.y := a.x*bTemp.y + a.y*bTemp.x;
    end;
  end;
end;}

{------------------------------------------------------------------------------}
function MaxCmplxReal(const Data: array of TComplex): TReal32;
var
  i: Integer;
begin
  Result := Data[Low(Data)].x;
  for I := Low(Data) + 1 to High(Data) do
    if Result < Data[I].x then Result := Data[I].x;
end;

{------------------------------------------------------------------------------}
function CMag(const a: TComplex): TReal32;
begin
  Result:= Sqrt(Sqr(a.x) + Sqr(a.y));
end;

{------------------------------------------------------------------------------}
function CPhi(const a: TComplex): TReal32;
begin
  Result:= Arctan(a.y / a.x);
end;

{------------------------------------------------------------------------------}
function MaxCmplxRealPos(const Data: array of TComplex): integer;
var
  i : integer;
  tempmax: TReal32;
begin
  result := Low(Data);
  tempmax := Data[Low(Data)].x;
  for i:= Low(Data) + 1 to High(Data) do
    if tempmax < Data[I].x then
    begin
      tempmax:= Data[i].x;
      Result:= i;
    end;
end;

{------------------------------------------------------------------------------}
function MaxMagPosn(const Data: array of TComplex): integer;
var
  i : integer;
  tempmax: TReal32;
begin
  result := Low(Data);
  tempmax := Sqr(Data[Low(Data)].x) + Sqr(Data[Low(Data)].y);
  for i:= Low(Data) + 1 to High(Data) div 2 do //div2... only search +ve frequencies
    if tempmax < (Sqr(Data[i].x) + Sqr(Data[i].y)) then
    begin
      tempmax:= Sqr(Data[i].x) + Sqr(Data[i].y);
      Result:= i;
    end;
end;

{------------------------------------------------------------------------------}
procedure Input2Volts(const InputBuffer : TWaveform{array of Word};
                      const Resolution  : word;
                          const ExtGain : TReal32;
                       var OutputBuffer : LPREAL32; //pointer allows indexing not only from start
                      // var OutputBuffer : TReal32Array;
                       const ADCVRange  : TReal32{default=20 volts, intgain 1x});
var i, Zero : integer;
      Scale : TReal32;
begin
  Zero:= 2 shl (Resolution - 2); //assumes bipolar, binary-offset input data
  Scale:= ADCVRange / ExtGain / (Zero * 2);
  for i:= Low(InputBuffer) to High(InputBuffer) do //convert...
  begin
    OutputBuffer^:= (InputBuffer[i] - Zero) * Scale;
    inc(OutputBuffer); //no range check for out of bounds!
  end;
end;

{------------------------------------------------------------------------------}
{ CRC32 calculates a cyclic redundancy code (CRC), known as CRC-32, using
 a byte-wise algorithm.

 (C) Copyright 1989, 1995-1996, 1999 Earl F. Glynn, Overland Park, KS.

 This UNIT was derived from the CRCT FORTRAN 77 program given in
 "Byte-wise CRC Calculations" by Aram Perez in IEEE Micro, June 1983,
 pp. 40-50.  The constants here are for the CRC-32 generator polynomial,
 as defined in the Microsoft Systems Journal, March 1995, pp. 107-108

 This CRC algorithm emphasizes speed at the expense of the 256-element
 lookup table.

 Updated for Delphi 4 dynamic arrays and stream I/O.  July 1999.}
{------------------------------------------------------------------------------}
procedure CalcCRC32 (p:  pointer; ByteCount:  DWord; var CRCValue:  DWord);
{The following is a little cryptic (but executes very quickly).
 The algorithm is as follows:
 1.  exclusive-or the input byte with the low-order byte of
     the CRC register to get an INDEX
 2.  shift the CRC register eight bits to the right
 3.  exclusive-or the CRC register with the contents of
     Table[INDEX]
 4.  repeat steps 1 through 3 for all bytes}
var
  i:  DWord;
  q:  ^byte;
begin
  q := p;
  for i := 0 to ByteCount-1 do
  begin
    CRCValue:= (CRCValue shr 8) xor CRCTable[q^ xor (CRCvalue and $000000FF) ];
    inc(q)
  end;
end;

{------------------------------------------------------------------------------}
procedure CalcFileCRC32 (FromName:  string; var CRCValue:  DWORD;
            var TotalBytes:  TInteger8;
            var error:  Word);
{  The CRC-32 value calculated here matches the one used by the PKZIP program.
  Use MemoryStream to read file in binary mode.}
var
  Stream:  TMemoryStream;
begin
  error := 0;
  CRCValue := $FFFFFFFF;
  Stream := TMemoryStream.Create;
  try
    try
      Stream.LoadFromFile(FromName);
      if Stream.Size > 0
        then CalcCRC32(Stream.Memory, Stream.Size, CRCvalue)
    except
      on E: EReadError do
        error := 1
    end;
    {CRCvalue := not CRCvalue;}
    TotalBytes := Stream.Size
  finally
    Stream.Free
  end;
end;

{------------------------------------------------------------------------------}
procedure ShellSort (var SortElements : array of integer;
                                Order : TSortOrder = ssAscending;
                     const IndexOrder : TIntArray = nil);
 { Shell-Metzner Sort }
 { Adapted from Programming in Pascal,
   P. Grogono, Addison-Wesley, 1980 }
var jump, i, j, temp : integer;
  Done: boolean;
begin
  jump:= Length(SortElements);
  while jump > 1 do
  begin
    jump:= jump div 2;
    repeat
      done:= True;
      for j:= Low(SortElements) to High(SortElements) - jump do
      begin
        i:= j + jump;
        case Order of
          ssAscending :
          begin
            if SortElements[j] > SortElements[i] then
            begin
              temp:= SortElements[i];
              SortElements[i]:= SortElements[j];
              SortElements[j]:= temp;
              if IndexOrder <> nil then
              begin
                temp:= IndexOrder[i];
                IndexOrder[i]:= IndexOrder[j];
                IndexOrder[j]:= temp;
              end;
              done:= False;
            end;
          end else {saDescending}
            if SortElements[j] < SortElements[i] then
            begin
              temp:= SortElements[i];
              SortElements[i]:= SortElements[j];
              SortElements[j]:= temp;
              if IndexOrder <> nil then
              begin
                temp:= IndexOrder[i];
                IndexOrder[i]:= IndexOrder[j];
                IndexOrder[j]:= temp;
              end;
              done:= False;
            end;
        end{case};
      end{j};
    until done;
  end{while};
end;

{------------------------------------------------------------------------------}
procedure ShellSort64(var SortElements : array of int64;
                      Order : TSortOrder = ssAscending;
                      const IndexOrder : TIntArray = nil);
 { Shell-Metzner Sort }
 { Adapted from Programming in Pascal,
   P. Grogono, Addison-Wesley, 1980 }
var jump, i, j : integer;
  temp : int64;
  Done : boolean;
begin
  jump:= Length(SortElements);
  while jump > 1 do
  begin
    jump:= jump div 2;
    repeat
      done:= True;
      for j:= Low(SortElements) to High(SortElements) - jump do
      begin
        i:= j + jump;
        case Order of
          ssAscending :
          begin
            if SortElements[j] > SortElements[i] then
            begin
              temp:= SortElements[i];
              SortElements[i]:= SortElements[j];
              SortElements[j]:= temp;
              if IndexOrder <> nil then
              begin
                temp:= IndexOrder[i];
                IndexOrder[i]:= IndexOrder[j];
                IndexOrder[j]:= temp;
              end;
              done:= False;
            end;
          end else {saDescending}
            if SortElements[j] < SortElements[i] then
            begin
              temp:= SortElements[i];
              SortElements[i]:= SortElements[j];
              SortElements[j]:= temp;
              if IndexOrder <> nil then
              begin
                temp:= IndexOrder[i];
                IndexOrder[i]:= IndexOrder[j];
                IndexOrder[j]:= temp;
              end;
              done:= False;
            end;
        end{case};
      end{j};
    until done;
  end{while};
end;

{------------------------------------------------------------------------------}
procedure CSD(const Waveforms : TWaveform; nDeltaY, NChans : integer;
              var CSDOut : array of TReal32);
{ Calculates 1D CSD from field potential waveforms by estimating
  the second spatial derivative with a finite difference formula:

              V(z + n) - 2V(z) + V(z - n)
  CSD(z) ~  _______________________________

                      (n x n)

  Assumes : i) fp waveforms are aligned equidistantly along one axis;
           ii) waveforms are of the same length, concatenated in (spatial) order;
          iii) a homogenous extracellular medium (eg. no laminar inhomogeneties)
           iv) nDeltaY is the differentiation grid size, usually 1 or 2
            v) that CSDOut is of the appropriate length }
var i, j, w : integer;
begin
  i:= 0; //index into CSD output array
  j:= Length(Waveforms) div NChans * nDeltaY; //index into field pot. waveforms
  for w:= j to high(Waveforms) - j do
  begin
    CSDOut[i]:= (Waveforms[w + j] - 2 * Waveforms[w] + Waveforms[w - j]) /
                                (ndeltaY * ndeltaY);
    inc(i);
  end;
end;

end{SurfMathLibrary}.
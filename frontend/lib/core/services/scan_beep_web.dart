// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Beep web — méthode universelle compatible Safari iOS, Chrome, Firefox.
/// Utilise un <audio> avec WAV généré en base64 (pas de user gesture requis).
JSObject? _lastAudio;

Future<void> playBeep() async {
  try {
    final audio = _createBeepAudio();
    if (audio == null) return;
    _lastAudio = audio;
    audio.callMethod('play'.toJS);
  } catch (_) {}
}

void initWebAudio() {} // no-op

JSObject? _createBeepAudio() {
  try {
    return globalContext.callMethod(
      'Function'.toJS,
      'return (function(){var sr=22050,dur=0.15,freq=1200;var n=Math.floor(sr*dur);var b=new Uint8Array(44+n*2);function ws(o,s){for(var i=0;i<s.length;i++)b[o+i]=s.charCodeAt(i);}ws(0,"RIFF");var sz=36+n*2;b[4]=sz&0xff;b[5]=(sz>>8)&0xff;b[6]=(sz>>16)&0xff;b[7]=(sz>>24)&0xff;ws(8,"WAVE");ws(12,"fmt ");b[16]=16;b[20]=1;b[22]=1;b[24]=sr&0xff;b[25]=(sr>>8)&0xff;b[26]=(sr>>16)&0xff;b[27]=(sr>>24)&0xff;var br=sr*2;b[28]=br&0xff;b[29]=(br>>8)&0xff;b[30]=(br>>16)&0xff;b[31]=(br>>24)&0xff;b[32]=2;b[34]=16;ws(36,"data");var ds=n*2;b[40]=ds&0xff;b[41]=(ds>>8)&0xff;b[42]=(ds>>16)&0xff;b[43]=(ds>>24)&0xff;for(var i=0;i<n;i++){var t=i/sr;var e=1-i/n;var v=Math.round(32767*0.9*Math.sin(2*Math.PI*freq*t)*e);b[44+i*2]=v&0xff;b[45+i*2]=(v>>8)&0xff;}var bin="";for(var i=0;i<b.length;i++)bin+=String.fromCharCode(b[i]);var b64=btoa(bin);var a=new Audio("data:audio/wav;base64,"+b64);a.volume=1.0;return a;})()'.toJS,
    );
  } catch (_) {
    return null;
  }
}

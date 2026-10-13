import 'dotenv/config';
import pg from 'pg';
const norm = (s)=>String(s??'').normalize('NFD').replace(/[̀-ͯ]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim();
const gs1ok=(e)=>{if(!/^\d{13}$/.test(e))return false;const d=e.slice(0,12).split('').map(Number);const s=d.reduce((a,x,i)=>a+x*(i%2===0?1:3),0);return (10-(s%10))%10===Number(e[12]);};
const rawUrl=process.env.DATABASE_URL??'';const connectionString=rawUrl.replace(/[?&]sslmode=[^&]*/g,'');
const c=new pg.Client({connectionString,ssl:{rejectUnauthorized:false}});
let pass=0,total=0;const check=(n,ok,d)=>{total++;if(ok)pass++;console.log(`${ok?'PASS':'FAIL'} | ${n}${d?' | '+d:''}`);};
try{await c.connect();
  const PID='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const withEan=(await c.query(`SELECT name,laboratory_name,barcode_ean13 FROM medications WHERE pharmacy_id=$1 AND barcode_ean13 IS NOT NULL AND barcode_ean13<>''`,[PID])).rows;
  check('au moins 1018 médicaments avec EAN (398 passe 1 + 620 passe 2)', withEan.length>=1018, `n=${withEan.length}`);
  // Tous checksums valides
  const invalid=withEan.filter(r=>!gs1ok(r.barcode_ean13));
  check('tous les EAN sont des checksums GS1 valides', invalid.length===0, invalid.length?JSON.stringify(invalid.slice(0,3)):`${withEan.length} valides`);
  // Unicité au sein de la pharmacie
  const eans=withEan.map(r=>r.barcode_ean13); const dupes=eans.filter((e,i)=>eans.indexOf(e)!==i);
  check('aucun EAN dupliqué en base', dupes.length===0, dupes.length?dupes.join(','):'ok');
  // Échantillon à vérifier manuellement contre RMMG
  console.log('\nÉchantillon importé (nom [labo] -> EAN) :');
  withEan.slice(0,12).forEach(r=>console.log(`  ${r.name} [${r.laboratory_name}] -> ${r.barcode_ean13}`));
  console.log(`\nVERIFY_IMPORT: ${pass}/${total}`);
  process.exit(pass===total?0:1);
}catch(e){console.error('ECHEC:',e.message);process.exit(1);}finally{await c.end();}

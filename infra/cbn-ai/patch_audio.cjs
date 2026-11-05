const fs=require('node:fs');const path=process.argv[2];let s=fs.readFileSync(path,'utf8');
const anchor="import Icon from 'next/icon/Icon.vue';";if(!s.includes(anchor)||s.includes('CbnAudioTranscription'))throw Error('Audio chip source changed');
s=s.replace(anchor,()=>anchor+"\nimport CbnAudioTranscription from 'next/cbn-ai/CbnAudioTranscription.vue';");
const where='    <div\n      v-if="attachment.transcribedText && showTranscribedText"';if(!s.includes(where))throw Error('Audio transcript anchor changed');
s=s.replace(where,()=> '    <CbnAudioTranscription :attachment="attachment" />\n\n'+where);fs.writeFileSync(path,s);

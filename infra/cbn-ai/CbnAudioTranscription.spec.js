import { mount, flushPromises } from '@vue/test-utils';
import { describe,it,expect,vi,beforeEach,afterEach } from 'vitest';
import CbnAudioTranscription from './CbnAudioTranscription.vue';
const attachment={id:123,accountId:1,transcribedText:''};
beforeEach(()=>{vi.useFakeTimers();global.axios={post:vi.fn(),get:vi.fn()};});
afterEach(()=>{vi.useRealTimers();});
describe('manual audio transcription',()=>{
 it('does not upload automatically and follows one explicit request to its result',async()=>{
  axios.post.mockResolvedValue({data:{state:'queued'}});axios.get.mockResolvedValue({data:{state:'done',text:'Áudio sintético de teste.'}});
  const w=mount(CbnAudioTranscription,{props:{attachment}});expect(axios.post).not.toHaveBeenCalled();
  await w.get('button').trigger('click');await flushPromises();expect(axios.post).toHaveBeenCalledTimes(1);
  await vi.advanceTimersByTimeAsync(3000);await flushPromises();expect(w.text()).toContain('Áudio sintético de teste.');w.unmount();
 });
 it('prevents duplicate clicks and shows a safe error',async()=>{
  let reject;axios.post.mockImplementation(()=>new Promise((_,r)=>{reject=r;}));
  const w=mount(CbnAudioTranscription,{props:{attachment}});await w.get('button').trigger('click');await w.get('button').trigger('click');expect(axios.post).toHaveBeenCalledTimes(1);
  reject({response:{data:{error:'Confira sua chave.'}}});await flushPromises();expect(w.get('[role="alert"]').text()).toBe('Confira sua chave.');w.unmount();
 });
 it('reuses a saved result and does not render a second native transcript',async()=>{
  axios.post.mockResolvedValue({data:{state:'done',text:'Já transcrito.'}});
  const w=mount(CbnAudioTranscription,{props:{attachment}});await w.get('button').trigger('click');await flushPromises();
  expect(w.text()).toContain('Já transcrito.');await w.setProps({attachment:{...attachment,transcribedText:'Já transcrito.'}});expect(w.find('button').exists()).toBe(false);expect(w.text()).toBe('');w.unmount();
 });
 it('stops polling on unmount and hides on other accounts',async()=>{
  axios.post.mockResolvedValue({data:{state:'queued'}});const w=mount(CbnAudioTranscription,{props:{attachment}});await w.get('button').trigger('click');await flushPromises();w.unmount();await vi.advanceTimersByTimeAsync(6000);expect(axios.get).not.toHaveBeenCalled();
  const other=mount(CbnAudioTranscription,{props:{attachment:{...attachment,accountId:2}}});expect(other.find('button').exists()).toBe(false);other.unmount();
 });
});

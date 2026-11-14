/**
 * 小步 Little Steps 的 Cloud Functions：只有 LLM 代理這一件事（docs/decisions.md A2）。
 * 不用 Firestore、不存孩子資料、不放 analytics。
 */
export { bubuLearn } from './bubuLearn';

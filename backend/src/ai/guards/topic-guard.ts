import { GeminiProvider } from '../providers/gemini.provider';
import { IntentRouter, GuardVerdict } from '../routers/intent.router';
import { prisma } from '../../utils/db.util';
import { costUsd, safeTokens } from '../pricing';
import { logger } from '../../utils/logger';

const router = new IntentRouter(new GeminiProvider());

/**
 * Checks that a free-text topic (quiz title, deck title, study-plan subjects) is
 * academic before any generation runs. Returns a student-facing error, or null if allowed.
 * Material generated from the student's own uploaded document skips this check.
 */
export async function checkStudyTopic(userId: string, topic: string): Promise<string | null> {
  const { verdict, costData } = await router.classifyTopic(topic);

  const promptTokens = safeTokens(costData.promptTokens);
  const completionTokens = safeTokens(costData.completionTokens);
  if (promptTokens > 0) {
    prisma.aiRequestLog.create({
      data: {
        userId,
        modelName: costData.modelName,
        promptTokens,
        completionTokens,
        totalTokens: promptTokens + completionTokens,
        cost: costUsd(costData.modelName, promptTokens, completionTokens),
        requestType: 'TOPIC_GUARD',
      },
    }).catch(err => logger.error({ err }, 'Failed to log cost'));
  }

  if (verdict === GuardVerdict.STUDY) return null;
  logger.info({ userId, verdict }, 'Topic guard blocked generation request');
  return verdict === GuardVerdict.OFF_TOPIC
    ? 'Study material can only be created for academic subjects. Please choose a study topic.'
    : "This topic can't be used to create study material. Please choose an academic subject.";
}

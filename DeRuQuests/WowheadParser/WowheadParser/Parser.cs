using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using CommandLine;

namespace WowheadParser
{
    internal class Parser
    {
        private const string QUEST_URL_PATTERN = @"http://{0}.wowhead.com/quest={1}";
        private const int MIN_QUEST_ID = 1790;
        private const int MAX_QUEST_ID = 1790;

        private readonly string _fromLanguage;
        private readonly string _toLanguage;

        public Parser(string fromLanguage, string toLanguage)
        {
            _fromLanguage = fromLanguage;
            _toLanguage = toLanguage;
        }

        public ConcurrentBag<string> Results { get; set; }

        public async Task<IDictionary<string, Quest>> ParseAsync()
        {
            var quests = new ConcurrentDictionary<string, Quest>();
            Results = new ConcurrentBag<string>();

            var ids = Enumerable.Range(MIN_QUEST_ID, MAX_QUEST_ID - MIN_QUEST_ID + 1);
            await AsyncParallel.ForEach(
                ids,
                async id =>
                      {
                          try
                          {
                              var translatedQuest = await parseQuestAsync(id);
                              if (translatedQuest != null)
                              {
                                  quests.AddOrUpdate(
                                      translatedQuest.OriginalTitle,
                                      translatedQuest.Quest,
                                      (s, q) => translatedQuest.Quest);

                                  var result = $"OK > Quest {id} parsed.";
                                  Results.Add(result);
                                  Console.WriteLine(result);
                              }
                              else
                              {
                                  var result = $"INVALID > Quest {id} is invalid.";
                                  Results.Add(result);
                                  Console.WriteLine(result);
                              }
                          }
                          catch (WebException)
                          {
                              var result = $"INVALID > Quest {id} doesn't exist.";
                              Results.Add(result);
                              Console.WriteLine(result);
                          }
                          catch (Exception e)
                          {
                              var result = $"EXCEPTION > [{e.GetType().Name}] {e.Message}";
                              Results.Add(result);
                              Console.WriteLine(result);
                          }
                      },
                20);

            return quests;
        }

        private async Task<TranslatedQuest> parseQuestAsync(int id)
        {
            using (var client = new WebClient())
            {
                client.Encoding = Encoding.UTF8;

                var translatedQuest = new TranslatedQuest();
                var quest = new Quest();

                // Get the quest title from the text in original language.
                var url = string.Format(QUEST_URL_PATTERN, _fromLanguage, id);
                var html = await client.DownloadStringTaskAsync(url);

                if (!isValidQuest(html))
                    return null;

                var originalTitle = getTitleText(html);
                if (originalTitle == null)
                    throw new ParserException($"Can't get the quest {id} title for language '{_fromLanguage}'.");

                translatedQuest.OriginalTitle = originalTitle;

                // Get the title, description, etc. of the translated quest.
                url = string.Format(QUEST_URL_PATTERN, _toLanguage, id);
                html = await client.DownloadStringTaskAsync(url);

                var title = getTitleText(html);
                if (title == null)
                    throw new ParserException($"Can't get the quest {id} title for language '{_toLanguage}'.");

                var description = getDescriptionText(html);
                if (description == null)
                    throw new ParserException($"Can't get the quest {id} description for language '{_toLanguage}'.");

                var progressText = getProgressText(html);

                var completionText = getCompletionText(html);
                if (completionText == null)
                    throw new ParserException($"Can't get the quest {id} completion text for language '{_toLanguage}'.");

                quest.Title = title;
                quest.Description = description;
                quest.ProgressText = progressText;
                quest.CompletionText = completionText;

                translatedQuest.Quest = quest;

                return translatedQuest;
            }
        }

        private static bool isValidQuest(string html)
        {
            return !html.Contains(@"style=""color: red""") &&
                   !html.Contains(@"id=""inputbox-error""");
        }

        private static string getTitleText(string html)
        {
            var match = Regex.Match(html, @"<h1 class=""heading-size-1"">(?<title>.+?)</h1>", RegexOptions.Singleline);
            return match.Success ? escapeText(match.Groups["title"].Value) : null;
        }

        private static string getDescriptionText(string html)
        {
            var match = Regex.Match(
                html, @"<h2 class=""heading-size-3"">.+?</h2>(?<desc>.+?)<h2", RegexOptions.Singleline);
            return match.Success ? escapeText(match.Groups["desc"].Value) : null;
        }

        private static string getProgressText(string html)
        {
            var match = Regex.Match(
                html,
                @"<div id=""lknlksndgg-progress"" style=""display: none"">(?<progress>.+?)</div>",
                RegexOptions.Singleline);
            return match.Success ? escapeText(match.Groups["progress"].Value) : null;
        }

        private static string getCompletionText(string html)
        {
            var match = Regex.Match(
                html,
                @"<div id=""lknlksndgg-completion"" style=""display: none"">(?<complete>.+?)</div>",
                RegexOptions.Singleline);
            return match.Success ? escapeText(match.Groups["complete"].Value) : null;
        }

        private static string escapeText(string text)
        {
            var escaped = text.Replace(@"<br />", " ")
                              .Replace(@"&lt;", "<")
                              .Replace(@"&gt;", ">")
                              .Trim();
            return Regex.Replace(escaped, @"\s+", @" ", RegexOptions.Singleline);
        }
    }
}
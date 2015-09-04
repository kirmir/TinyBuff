using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Threading.Tasks.Dataflow;

namespace WowheadParser
{
    public static class AsyncParallel
    {
        public static Task ForEach<T>(
            IEnumerable<T> source,
            Func<T, Task> action,
            int maxDegreeOfParallelism = DataflowBlockOptions.Unbounded,
            TaskScheduler scheduler = null)
        {
            var options = new ExecutionDataflowBlockOptions { MaxDegreeOfParallelism = maxDegreeOfParallelism };
            if (scheduler != null)
            {
                options.TaskScheduler = scheduler;
            }

            var block = new ActionBlock<T>(action, options);

            foreach (var item in source)
            {
                block.Post(item);
            }

            block.Complete();

            return block.Completion;
        }
    }
}
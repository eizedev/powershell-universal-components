using System;
using System.IO;
using System.Net.Http;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;

namespace PivotReportHttp
{
    public static class Transport_SUFFIX
    {
        private static int activeReaders;

        /// <summary>Background readers still running, for the tests: each ends with its connection.</summary>
        public static int ActiveReaders => Volatile.Read(ref activeReaders);

        /// <summary>The stream a connection of NewHandler uses, over a connected socket (for the tests).</summary>
        public static Stream Open(Socket socket) => new ReadAheadStream(socket);

        /// <summary>A handler without redirects or cookies whose connections keep an early answer.</summary>
        public static SocketsHttpHandler NewHandler()
        {
            var handler = new SocketsHttpHandler
            {
                AllowAutoRedirect = false,
                UseCookies = false,
                AutomaticDecompression = System.Net.DecompressionMethods.All
            };
            handler.ConnectCallback = async (context, cancel) =>
            {
                var socket = new Socket(SocketType.Stream, ProtocolType.Tcp) { NoDelay = true };
                try
                {
                    await socket.ConnectAsync(context.DnsEndPoint, cancel).ConfigureAwait(false);
                    return new ReadAheadStream(socket);
                }
                catch
                {
                    socket.Dispose();
                    throw;
                }
            };
            return handler;
        }

        private sealed class ReadAheadStream : Stream
        {
            // how long a failed write waits for the answer that may have caused it
            private const int AnswerWaitMs = 2000;
            private readonly NetworkStream inner;
            // at most 256 reads of 16 KiB ahead of the reader
            private readonly Channel<byte[]> received = Channel.CreateBounded<byte[]>(new BoundedChannelOptions(256) { SingleReader = true, SingleWriter = true });
            private byte[] current = Array.Empty<byte>();
            private int offset;
            // bytes received and not read yet
            private long unread;
            private volatile bool ended;
            // set once a write failed after the server had started to answer: the rest of the body is
            // dropped on purpose, without an error, so the request goes on to read that answer (a 413
            // for a body over the cap). Any byte received counts as the start of an answer, as the
            // request is sent without Expect: 100-continue
            private volatile bool dropping;
            // ends the background reader's wait for room in the buffer when the stream is disposed
            private readonly CancellationTokenSource closing = new CancellationTokenSource();
            // 1 once disposed: a stream may be disposed more than once (HttpClient and its connection)
            private int disposed;

            public ReadAheadStream(Socket socket)
            {
                inner = new NetworkStream(socket, ownsSocket: true);
                _ = PumpAsync();
            }

            private async Task PumpAsync()
            {
                var buffer = new byte[16384];
                Interlocked.Increment(ref activeReaders);
                try
                {
                    while (true)
                    {
                        int n = await inner.ReadAsync(buffer.AsMemory()).ConfigureAwait(false);
                        if (n == 0) break;
                        Interlocked.Add(ref unread, n);
                        await received.Writer.WriteAsync(buffer.AsSpan(0, n).ToArray(), closing.Token).ConfigureAwait(false);
                    }
                    received.Writer.TryComplete();
                }
                catch (Exception e)
                {
                    received.Writer.TryComplete(e is IOException ? e : new IOException(e.Message, e));
                }
                finally
                {
                    ended = true;
                    Interlocked.Decrement(ref activeReaders);
                }
            }

            public override async ValueTask<int> ReadAsync(Memory<byte> destination, CancellationToken cancellationToken = default)
            {
                while (offset >= current.Length)
                {
                    if (!await received.Reader.WaitToReadAsync(cancellationToken).ConfigureAwait(false)) return 0;
                    // a zero-byte read only waits until there is something to read
                    if (destination.Length == 0) return 0;
                    if (received.Reader.TryRead(out var next)) { current = next; offset = 0; }
                }
                int count = Math.Min(destination.Length, current.Length - offset);
                current.AsMemory(offset, count).CopyTo(destination);
                offset += count;
                Interlocked.Add(ref unread, -count);
                return count;
            }

            public override async ValueTask WriteAsync(ReadOnlyMemory<byte> source, CancellationToken cancellationToken = default)
            {
                if (dropping) return;
                try
                {
                    await inner.WriteAsync(source, cancellationToken).ConfigureAwait(false);
                }
                catch (IOException)
                {
                    // the server stopped taking the body: when it answered, the answer is what counts
                    for (int waited = 0; Interlocked.Read(ref unread) == 0 && !ended && waited < AnswerWaitMs; waited += 10)
                    {
                        await Task.Delay(10, CancellationToken.None).ConfigureAwait(false);
                    }
                    if (Interlocked.Read(ref unread) == 0) throw;
                    dropping = true;
                }
            }

            public override Task<int> ReadAsync(byte[] buffer, int index, int count, CancellationToken cancellationToken) => ReadAsync(buffer.AsMemory(index, count), cancellationToken).AsTask();
            public override Task WriteAsync(byte[] buffer, int index, int count, CancellationToken cancellationToken) => WriteAsync(buffer.AsMemory(index, count), cancellationToken).AsTask();
            public override int Read(byte[] buffer, int index, int count) => ReadAsync(buffer.AsMemory(index, count)).AsTask().GetAwaiter().GetResult();
            public override void Write(byte[] buffer, int index, int count) => WriteAsync(buffer.AsMemory(index, count)).AsTask().GetAwaiter().GetResult();
            public override void Flush() { if (!dropping) inner.Flush(); }
            public override Task FlushAsync(CancellationToken cancellationToken) => dropping ? Task.CompletedTask : inner.FlushAsync(cancellationToken);
            public override bool CanRead => true;
            public override bool CanWrite => true;
            public override bool CanSeek => false;
            public override long Length => throw new NotSupportedException();
            public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
            public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
            public override void SetLength(long value) => throw new NotSupportedException();

            protected override void Dispose(bool disposing)
            {
                if (disposing && Interlocked.Exchange(ref disposed, 1) == 0)
                {
                    // a reader waiting for room in a full buffer wakes up and ends, so neither the task
                    // nor its buffers outlive the connection
                    received.Writer.TryComplete();
                    closing.Cancel();
                    inner.Dispose();
                    closing.Dispose();
                }
                base.Dispose(disposing);
            }
        }
    }
}

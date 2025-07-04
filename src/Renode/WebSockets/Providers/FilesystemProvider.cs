using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;

namespace Antmicro.Renode.WebSockets.Providers
{
    class FilesystemProvider : IWebSocketAPIProvider
    {
        public FilesystemProvider()
        {

        }

        public bool Start(WebSocketAPISharedData sharedData)
        {
            SharedData = sharedData;
            return true;
        }

        [WebSocketAPIAction("fs/list", "1.5.0")]
        private WebSocketAPIResponse ListFilesAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                var filesResult = Directory
                    .GetFiles(fullPath)?
                    .Select(f => PathInfo(f));

                var dirResult = Directory
                    .GetDirectories(fullPath)?
                    .Select(d => PathInfo(d));

                var result = filesResult.Concat(dirResult);

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse();
            }
        }

        [WebSocketAPIAction("fs/mkdir", "1.5.0")]
        private WebSocketAPIResponse MakeDirectoryAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                Directory.CreateDirectory(fullPath);
                return WebSocketAPIUtils.CreateEmptyActionResponse();
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/stat", "1.5.0")]
        private WebSocketAPIResponse FileInfoAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);

                if(File.Exists(fullPath))
                {
                    var fileInfo = new FileInfo(fullPath);
                    var fileAttr = File.GetAttributes(fullPath);

                    var ctime = new DateTimeOffset(fileInfo.CreationTime);
                    var mtime = new DateTimeOffset(fileInfo.LastWriteTime);

                    var result = new StatActionResponseDto
                    {
                        success = true,
                        size = fileInfo.Length,
                        isfile = true,
                        ctime = Convert.ToSingle(ctime.ToUnixTimeSeconds()),
                        mtime = Convert.ToSingle(mtime.ToUnixTimeSeconds())
                    };

                    return WebSocketAPIUtils.CreateActionResponse(result);
                }
                else if(Directory.Exists(fullPath))
                {
                    var directoryInfo = new DirectoryInfo(fullPath);

                    var ctime = new DateTimeOffset(directoryInfo.CreationTime);
                    var mtime = new DateTimeOffset(directoryInfo.LastWriteTime);

                    var result = new StatActionResponseDto
                    {
                        success = true,
                        size = -1,
                        isfile = false,
                        ctime = Convert.ToSingle(ctime.ToUnixTimeSeconds()),
                        mtime = Convert.ToSingle(mtime.ToUnixTimeSeconds())
                    };

                    return WebSocketAPIUtils.CreateActionResponse(result);
                }
                else
                {
                    return WebSocketAPIUtils.CreateEmptyActionResponse($"{fullPath} does not exist");
                }
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/dwnl", "1.5.0")]
        private WebSocketAPIResponse DownloadAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                var data = File.ReadAllBytes(fullPath);
                var result = Convert.ToBase64String(data);

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/upld", "1.5.0")]
        private WebSocketAPIResponse UploadAction(List<string> args, string data)
        {
            try
            {
                var bytes = Convert.FromBase64String(data);
                var path = ResolvePath(args[0]);
                var directory = Path.GetDirectoryName(path);
                Directory.CreateDirectory(directory);
                File.WriteAllBytes(path, bytes);

                return WebSocketAPIUtils.CreateActionResponse(new PathActionResponseDto
                {
                    success = true,
                    path = path
                });
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/remove", "1.5.0")]
        private WebSocketAPIResponse RemoveAction(List<string> args)
        {
            try
            {
                var fullPath = ResolvePath(args[0]);
                File.Delete(fullPath);

                var result = new PathActionResponseDto
                {
                    success = true,
                    path = fullPath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/move", "1.5.0")]
        private WebSocketAPIResponse MoveAction(List<string> args)
        {
            try
            {
                var oldPath = ResolvePath(args[0]);
                var newPath = ResolvePath(args[1]);

                File.Move(oldPath, newPath);

                var result = new MoveActionResponseDto
                {
                    success = true,
                    from = oldPath,
                    to = newPath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/copy", "1.5.0")]
        private WebSocketAPIResponse CopyAction(List<string> args)
        {
            try
            {
                var filePath = ResolvePath(args[0]);
                var newFilePath = ResolvePath(args[1]);
                File.Copy(filePath, newFilePath);

                var result = new MoveActionResponseDto
                {
                    success = true,
                    from = filePath,
                    to = newFilePath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/fetch", "1.5.0")]
        private WebSocketAPIResponse FetchAction(List<string> args)
        {
            try
            {
                var url = args[0];
                var uri = new Uri(url);
                var fileName = System.IO.Path.GetFileName(uri.LocalPath);
                var newFilePath = ResolvePath(fileName);

                using(var client = new WebClient())
                {
                    client.DownloadFile(url, newFilePath);
                }

                var result = new PathActionResponseDto
                {
                    success = true,
                    path = newFilePath
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("fs/zip", "1.5.0")]
        private WebSocketAPIResponse ZipAction(List<string> args)
        {
            try
            {
                var url = args[0];
                var uri = new Uri(url);
                var tempZipPath = ResolvePath("temp.zip");

                using(var client = new WebClient())
                {
                    client.DownloadFile(url, tempZipPath);
                }

                ZipFile.ExtractToDirectory(tempZipPath, SharedData.Cwd.Value, true);

                var result = new PathActionResponseDto
                {
                    success = true,
                    path = SharedData.Cwd.Value
                };

                return WebSocketAPIUtils.CreateActionResponse(result);
            }
            catch(Exception e)
            {
                return WebSocketAPIUtils.CreateEmptyActionResponse(e.Message);
            }
        }

        [WebSocketAPIAction("tweak/socket", "1.5.0")]
        private WebSocketAPIResponse TweakSocketAction(List<string> args)
        {
            var result = new StatusActionResponseDto
            {
                success = true
            };

            return WebSocketAPIUtils.CreateActionResponse(result);
        }

        private string ResolvePath(string path, string basePath = null)
        {
            if(basePath == null)
            {
                basePath = SharedData.Cwd.Value;
            }

            if(Path.IsPathRooted(path))
            {
                var parts = path.Split(Path.DirectorySeparatorChar);
                var pathWithoutRoot = parts.Skip(1).Aggregate((p1, p2) => $"{p1}/{p2}");
                return Path.Combine(basePath, pathWithoutRoot);
            }

            return Path.Combine(basePath, path);
        }

        private PathInfoDto PathInfo(string path)
        {
            var fileAttr = File.GetAttributes(path);

            return new PathInfoDto
            {
                name = Path.GetFileName(path),
                isfile = !fileAttr.HasFlag(FileAttributes.Directory),
                islink = fileAttr.HasFlag(FileAttributes.ReparsePoint)
            };
        }

        private WebSocketAPISharedData SharedData;

        private class StatusActionResponseDto
        {
            public bool success;
        }

        private class PathActionResponseDto
        {
            public bool success;
            public string path;
        }

        private class PathInfoDto
        {
            public string name;
            public bool isfile;
            public bool islink;
        }

        private class MoveActionResponseDto
        {
            public bool success;
            public string from;
            public string to;
        }

        private class StatActionResponseDto
        {
            public bool success;
            public long size;
            public bool isfile;
            public float ctime;
            public float mtime;
        }
    }
}
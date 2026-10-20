
<?php

use Aws\S3\S3Client;

// Создаём один S3-клиент на протяжении PHP-запроса.
// SDK автоматически получит временные credentials из IAM Role EC2.
function storage_client(): S3Client
{
    static $client = null;

    if ($client === null) {
        $client = new S3Client([
            'region' => config('AWS_REGION', 'eu-central-1'),
            'version' => 'latest',
        ]);
    }

    return $client;
}

// Имя бакета берём из .env.
function storage_bucket(): string
{
    $bucket = config('S3_BUCKET');

    if ($bucket === null) {
        throw new RuntimeException('S3_BUCKET is not configured.');
    }

    return $bucket;
}

// Все вложения хранятся в префиксе uploads/.
function storage_key(string $storedName): string
{
    return 'uploads/' . basename($storedName);
}

// Загружаем файл в S3 и возвращаем случайное имя для БД.
function storage_save(array $uploadedFile, string $extension): string
{
    $storedName = bin2hex(random_bytes(16)) . '.' . $extension;

    $mime = mime_content_type($uploadedFile['tmp_name'])
        ?: 'application/octet-stream';

    storage_client()->putObject([
        'Bucket' => storage_bucket(),
        'Key' => storage_key($storedName),
        'SourceFile' => $uploadedFile['tmp_name'],
        'ContentType' => $mime,
    ]);

    return $storedName;
}

// Удаляем объект. При включённом Versioning S3 создаст delete marker.
function storage_delete(?string $storedName): void
{
    if ($storedName === null || $storedName === '') {
        return;
    }

    storage_client()->deleteObject([
        'Bucket' => storage_bucket(),
        'Key' => storage_key($storedName),
    ]);
}

// Создаём временную ссылку на 5 минут.
// Проверка прав пользователя выполняется раньше, в контроллере.
function storage_stream(
    string $storedName,
    string $mime,
    string $downloadName,
    string $disposition
): void {
    $disposition = $disposition === 'attachment'
        ? 'attachment'
        : 'inline';

    $asciiName = preg_replace(
        '/[^A-Za-z0-9._ -]/',
        '_',
        $downloadName
    );

    $safeAsciiName = str_replace(
        ['\\', '"'],
        ['\\\\', '\\"'],
        $asciiName
    );

    $contentDisposition = sprintf(
        "%s; filename=\"%s\"; filename*=UTF-8''%s",
        $disposition,
        $safeAsciiName,
        rawurlencode($downloadName)
    );

    $command = storage_client()->getCommand('GetObject', [
        'Bucket' => storage_bucket(),
        'Key' => storage_key($storedName),
        'ResponseContentType' => $mime,
        'ResponseContentDisposition' => $contentDisposition,
    ]);

    $request = storage_client()->createPresignedRequest(
        $command,
        '+5 minutes'
    );

    header('Location: ' . (string) $request->getUri(), true, 302);
    exit;
}

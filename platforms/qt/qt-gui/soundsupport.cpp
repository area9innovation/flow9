#include "soundsupport.h"

#include <QDir>
#include <QBuffer>

#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(QtSound, AbstractSound)

void QtSound::beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady) {
    AbstractSound::beginLoad(url, onFail, onReady);

    QString fname = unicode2qt(url);
    player = new QMediaPlayer();

    connect(player, SIGNAL(error(QMediaPlayer::Error)),
            this, SLOT(handleError(QMediaPlayer::Error)));
    connect(player, SIGNAL(mediaStatusChanged(QMediaPlayer::MediaStatus)),
            this, SLOT(handleMediaStatusChanged(QMediaPlayer::MediaStatus)));

    if (QFile::exists(fname)) {
        QUrl mediaUrl = QUrl::fromLocalFile(QFileInfo(fname).absoluteFilePath());
        player->setMedia(mediaUrl);
    } else {
        QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
        QUrl full_url = base.resolved(QUrl(fname));
        QNetworkRequest request(full_url);
        reply = static_cast<QtSoundSupport*>(owner)->manager->get(request);
        connect(reply, SIGNAL(finished()), SLOT(finished()));
    }
}

void QtSound::handleError(QMediaPlayer::Error error) {
    QString message = QString("Media error: %1").arg(player->errorString());
    resolveError(qt2unicode(message));
}

void QtSound::handleMediaStatusChanged(QMediaPlayer::MediaStatus status) {
    if (status == QMediaPlayer::LoadedMedia) {
        resolveReady();
    }
}

void QtSound::finished() {
    reply->deleteLater();

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    if (reply->error() == QNetworkReply::NoError) {
        data = reply->readAll();
        QBuffer* buffer = new QBuffer(&data, this);
        buffer->open(QIODevice::ReadOnly);
        player->setMedia(QMediaContent(), buffer);
    } else {
        QString message = QString::number(reply->error()) + ' ' + reply->errorString();
        resolveError(qt2unicode(message));
    }

    getFlowRunner()->NotifyHostEvent(NativeMethodHost::HostEventNetworkIO);
}

float QtSound::computeSoundLength() {
    if (player) {
        qint64 duration = player->duration();
        return duration;// / 1000.0f;  // Convert ms to seconds
    }
    return 0.0f;
}

IMPLEMENT_FLOW_NATIVE_OBJECT(QtSoundChannel, AbstractSoundChannel)

void QtSoundChannel::beginPlay(float start_pos, bool loop, StackSlot onDone) {
    AbstractSoundChannel::beginPlay(start_pos, loop, onDone);

    QtSound* qtSound = flow_native_cast<QtSound>(sound);
    if (!qtSound || !qtSound->player) {
        notifyDone();
        return;
    }

    player = qtSound->player;
    looping = loop;

    connect(player, SIGNAL(stateChanged(QMediaPlayer::State)),
            this, SLOT(handleStateChanged(QMediaPlayer::State)));

    player->setPosition(qint64(start_pos)); // start_pos * 1000 to convert seconds to ms
    player->play();
}

void QtSoundChannel::handleStateChanged(QMediaPlayer::State state) {
    if (state == QMediaPlayer::StoppedState) {
        if (looping) {
            player->setPosition(0);
            player->play();
        } else {
            notifyDone();
        }
    }
}

void QtSoundChannel::setVolume(float value) {
    if (player) {
        player->setVolume(int(value * 100));
    }
}

void QtSoundChannel::stopSound() {
    AbstractSoundChannel::stopSound();
    if (player) {
        player->stop();
    }
}

float QtSoundChannel::getSoundPosition() {
    if (player) {
        return player->position();// / 1000.0f;  // Convert ms to seconds
    }
    return 0.0f;
}

QtSoundSupport::QtSoundSupport(ByteCodeRunner *Runner)
    : AbstractSoundSupport(Runner),
      manager(new QNetworkAccessManager(this))
{
}

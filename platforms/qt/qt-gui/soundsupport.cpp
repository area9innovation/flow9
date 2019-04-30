#include "soundsupport.h"

#include <QDir>
#include <QBuffer>

#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(QtSound, AbstractSound)

void QtSound::beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady)
{
    AbstractSound::beginLoad(url, onFail, onReady);

    QString fname = unicode2qt(url);

    if (QFile::exists(fname)) {
        //source = Phonon::MediaSource(fname);
        resolveReady();
    } else {
        QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
        QUrl full_url = base.resolved(QUrl(fname));
        QNetworkRequest request(full_url);
        reply = static_cast<QtSoundSupport*>(owner)->manager->get(request);
        connect(reply, SIGNAL(finished()), SLOT(finished()));
    }
}

void QtSound::finished()
{
    reply->deleteLater();

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    if (reply->error() == QNetworkReply::NoError) {
        data = reply->readAll();
        //source = Phonon::MediaSource(new QBuffer(&data, this));
        resolveReady();
    } else {
        QString message = QString::number(reply->error()) + ' ' + reply->errorString();
        resolveError(qt2unicode(message));
    }

    getFlowRunner()->NotifyHostEvent(NativeMethodHost::HostEventNetworkIO);
}

IMPLEMENT_FLOW_NATIVE_OBJECT(QtSoundChannel, AbstractSoundChannel)

void QtSoundChannel::beginPlay(float start_pos, bool loop, StackSlot onDone)
{
    // AbstractSoundChannel::beginPlay(start_pos, loop, onDone);

    // MediaObject = new Phonon::MediaObject(this);
    // MediaObject->setCurrentSource(flow_native_cast<QtSound>(sound)->source);

    // AudioOutput = new Phonon::AudioOutput(this);
    // Phonon::createPath(MediaObject, AudioOutput);

    // connect(MediaObject, SIGNAL(finished()), this, SLOT(finished()));
    // MediaObject->play();
}

void QtSoundChannel::finished()
{
    // MediaObject->deleteLater();
    // MediaObject = NULL;
    // AudioOutput->deleteLater();
    // AudioOutput = NULL;

    // notifyDone();
}

void QtSoundChannel::setVolume(float value)
{
    // if (AudioOutput)
    //     AudioOutput->setVolume(value);
}

void QtSoundChannel::stopSound()
{
    // AbstractSoundChannel::stopSound();

    // if (MediaObject)
    //     MediaObject->stop();

    // delete MediaObject; MediaObject = NULL;
    // delete AudioOutput; AudioOutput = NULL;
}

float QtSoundChannel::getSoundPosition()
{
    // if (MediaObject)
    //     return MediaObject->currentTime();
    // else
        return 0.0f;
}

QtSoundSupport::QtSoundSupport(ByteCodeRunner *Runner)
    : AbstractSoundSupport(Runner),
      manager(new QNetworkAccessManager(this))
{
}

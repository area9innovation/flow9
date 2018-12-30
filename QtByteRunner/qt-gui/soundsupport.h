#ifndef SOUNDSUPPORT_H
#define SOUNDSUPPORT_H

#include "utils/AbstractSoundSupport.h"

// #if defined(linux) || defined(__APPLE__)
// #include <phonon/mediaobject.h>
// #include <phonon/audiooutput.h>
// #include <phonon/mediasource.h>
// #else
// #include <Phonon/MediaObject>
// #include <Phonon/AudioOutput>
// #include <Phonon/MediaSource>
// #endif

#include <QNetworkAccessManager>
#include <QNetworkReply>

class QtSound : public QObject, public AbstractSound
{
    Q_OBJECT

protected:
    friend class QtSoundChannel;

    //Phonon::MediaSource source;

    QNetworkReply *reply;
    QByteArray data;

public:
    QtSound(AbstractSoundSupport *owner) : AbstractSound(owner), reply(NULL) {}

    virtual void beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady);

    DEFINE_FLOW_NATIVE_OBJECT(QtSound, AbstractSound);

private slots:
    void finished();
};

class QtSoundChannel : public QObject, public AbstractSoundChannel
{
    Q_OBJECT

protected:
    //Phonon::MediaObject *MediaObject;
    //Phonon::AudioOutput *AudioOutput;

    virtual void setVolume(float value);
    virtual void stopSound();
    virtual float getSoundPosition();

private slots:
    void finished();

public:
    QtSoundChannel(AbstractSoundSupport *owner, AbstractSound *snd)
        // : AbstractSoundChannel(owner, snd), MediaObject(NULL), AudioOutput(NULL)
        : AbstractSoundChannel(owner, snd)
    {}

    virtual void beginPlay(float start_pos, bool loop, StackSlot onDone);

    DEFINE_FLOW_NATIVE_OBJECT(QtSoundChannel, AbstractSoundChannel);
};

class QtSoundSupport : public QObject, public AbstractSoundSupport
{
    Q_OBJECT

    friend class QtSound;
    QNetworkAccessManager *manager;

public:
    QtSoundSupport(ByteCodeRunner *Runner);

protected:
    virtual AbstractSound *makeSound() { return new QtSound(this); }
    virtual AbstractSoundChannel *makeSoundChannel(AbstractSound *sound) { return new QtSoundChannel(this, sound); }
};

#endif // SOUNDSUPPORT_H

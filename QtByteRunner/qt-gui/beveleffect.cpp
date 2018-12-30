#include "beveleffect.h"
#include "math.h"

static void Blur(QImage & im, int radius)
{
    int height = im.height();
    int width = im.width();

    QImage src = im.copy(-radius, -radius, width + radius*2, height + radius*2);

    // Horizontal blur
    for (int y = 0; y < height; ++y)
    {
        const uint32_t *src_y_r = (const uint32_t*)src.scanLine(y + radius);
        uint32_t *im_y = (uint32_t*)im.scanLine(y);

        uint64_t sum = 0;
        for (int x = 0; x < 2 * radius; ++x)
            sum += src_y_r[x];

        for (int x = 0; x < width; ++x)
        {
            sum += src_y_r[x + 2 * radius];
            im_y[x] = sum / ( 2 * radius + 1);
            sum -= src_y_r[x];
        }
    }

    src = im.copy(-radius, -radius, width + radius*2, height + radius*2);

    // Vertical blur
    for (int x0 = 0, xtop = 32; x0 < width; x0 = xtop, xtop += 32)
    {
        if (xtop > width)
            xtop = width;

        uint64_t sum[32] = { 0 };

        for (int y = 0; y < 2 * radius; ++y)
        {
            const uint32_t *src_y = (const uint32_t*)src.scanLine(y);

            for (int x = x0, i = 0; x < xtop; x++, i++)
                sum[i] += src_y[x + radius];
        }

        for (int y = 0; y < height; ++y)
        {
            const uint32_t *src_y_2r = (const uint32_t*)src.scanLine(y + 2*radius);

            for (int x = x0, i = 0; x < xtop; x++, i++)
                sum[i] += src_y_2r[x + radius];

            uint32_t *im_y = (uint32_t*)im.scanLine(y);

            for (int x = x0, i = 0; x < xtop; x++, i++)
                im_y[x] = sum[i] / (2*radius + 1);

            const uint32_t *src_y = (const uint32_t*)src.scanLine(y);

            for (int x = x0, i = 0; x < xtop; x++, i++)
                sum[i] -= src_y[x + radius];
        }
    }
}

static void SubtractAlpha(QImage &target, const QImage &alpha, int dx, int dy)
{
    int target_bx = 0, alpha_bx = 0, target_by = 0, alpha_by = 0;
    int height = target.height();
    int width = target.width();

    width -= abs(dx);
    if (dx > 0)
        target_bx = dx;
    else
        alpha_bx = -dx;

    height -= abs(dy);
    if (dy > 0)
        target_by = dy;
    else
        alpha_by = -dy;

    for (int i = 0; i < height; ++i)
    {
        QRgb *line_target = ((QRgb*)target.scanLine(i + target_by)) + target_bx;
        const QRgb *line_alpha = ((const QRgb*)alpha.scanLine(i + alpha_by)) + alpha_bx;

        for (int j = 0; j < width; ++j)
        {
            QRgb tgt = line_target[j];
            int alpha = qAlpha(tgt) - qAlpha(line_alpha[j]);
            if (alpha < 0)
                alpha = 0;
            line_target[j] = qRgba(qRed(tgt), qGreen(tgt), qBlue(tgt), alpha);
        }
    }
}

BevelEffect::BevelEffect(qreal angle, uint offset, uint radius, uint color_up, qreal alpha_up,
                         uint color_down, qreal alpha_down) :
    AlphaUp(alpha_up), AlphaDown(alpha_down), ColorUp(color_up), ColorDown(color_down),
    Angle(angle), Offset(offset), Radius(radius)
{
} 

void BevelEffect::sourceChanged (ChangeFlags flags)
 {
     if (flags & SourceDetached)
         return;

     // Invalidate the pixmap
     ShadePx = QPixmap();
 }

void BevelEffect::MakeShadePixmap(const QPixmap &source)
{
    // We are interested only in the alpha channel here
    QImage mask = source.toImage().convertToFormat(QImage::Format_ARGB32);

    Blur(mask, Radius);

    double offset_x = Offset * sin(Angle / 180.0 * M_PI);
    double offset_y = Offset * cos(Angle / 180.0 * M_PI);

    // Create masks for each of the colors and subtract
    QImage mask1(mask.copy());
    SubtractAlpha(mask1, mask, offset_x*2, offset_y*2);

    QImage mask2(mask.copy());
    SubtractAlpha(mask2, mask, -offset_x*2, -offset_y*2);

    // Fill mask images with color, while keeping alpha
    QPainter maskPainter;
    maskPainter.begin(&mask1);
    maskPainter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    maskPainter.fillRect(QRect(QPoint(0,0), mask.size()), QColor::fromRgb(ColorUp));
    maskPainter.end();

    maskPainter.begin(&mask2);
    maskPainter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    maskPainter.fillRect(QRect(QPoint(0,0), mask.size()), QColor::fromRgb(ColorDown));
    maskPainter.end();

    // Make a combined shade pixmap by adding up the color masks
    ShadePx = QPixmap(source.size());
    ShadePx.fill(QColor::fromRgba(0));

    maskPainter.begin(&ShadePx);
    maskPainter.setCompositionMode(QPainter::CompositionMode_Plus);
    maskPainter.drawImage(-offset_x, -offset_y, mask1);
    maskPainter.drawImage(offset_x, offset_y, mask2);
    maskPainter.end();
}

void BevelEffect::draw( QPainter *painter )
{            
    // Check for no-op
    if (Radius == 0 && Offset == 0) {
        drawSource(painter);
        return;
    }

    // Draw pixmap in device coordinates to avoid pixmap scaling.
    QPoint offset;
    const QPixmap pixmap = sourcePixmap(Qt::DeviceCoordinates, &offset);
    if (pixmap.isNull())
        return;

    // Refresh the shade pixmap if needed
    if (ShadePx.isNull() || ShadePx.size() != pixmap.size())
        MakeShadePixmap(pixmap);

    // Use a temporary copy of the source
    QPixmap tmp(pixmap.copy());

    // Blend the shade mask in with the source, combining both alpha and color.
    // The resulting alpha should be the same as of the object originally.
    QPainter tmpPainter(&tmp);
    tmpPainter.setCompositionMode(QPainter::CompositionMode_SourceAtop);
    tmpPainter.drawPixmap(0, 0, ShadePx);
    tmpPainter.end();

    // Blit the temporary buffer
    QTransform restoreTransform = painter->worldTransform();
    painter->setWorldTransform(QTransform());
    painter->drawPixmap(offset, tmp);
    painter->setWorldTransform(restoreTransform);
}

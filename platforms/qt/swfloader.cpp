#include "swfloader.h"
#include <stdio.h>
#include <stdint.h>
#include <QtGui>

#define LE2BE32(x)  ((((x) & 0xFF000000) >> 24) | (((x) & 0x00FF0000) >> 8) | (((x) & 0x0000FF00) << 8) | (((x) & 0x000000FF) << 24))

typedef enum 
{
    //Unknown = -1,
    End = 0,
    JpegTable = 8,
    DefineBitsLossLess = 20,
    DefineBitsJpeg2 = 21, // Qt doesnot support such JPEG codestream. May be image plugin helps
    DefineBitsJpeg3 = 35,
    DefineBitsLossLess2 = 36       
} Tags;

typedef struct
{
    uint8_t  Signature[3];
    uint8_t  Version;
    uint32_t FileLength;
} Header;

template < typename T >
static inline bool GetValue(T & value, uint8_t * & data, uint32_t & data_length)
{
    if (data_length < sizeof(value))
        return false;
    
    value = * (T*) data; data += sizeof(T); data_length -= sizeof(T);    
    return true;
}

static QPixmap GetFirstImage(QByteArray & data_array)
{
    uint8_t * data = (uint8_t *) data_array.data();
    uint32_t data_length = data_array.length();    
    
    uint8_t rect_nbits = 0;        
    GetValue(rect_nbits, data, data_length);
    rect_nbits = (rect_nbits & 0xF8) >> 3;
    uint32_t bytes_count = ((rect_nbits * 4) - 3 + 7) / 8;      
    data += bytes_count; data_length -= bytes_count; // Skip frame size
    
    data += 2 * sizeof(uint16_t); data_length -= 2 * sizeof(uint16_t); // Skip rate and count
    
    uint16_t tag; uint32_t tag_len;   
    
    for (;;)
    {        
        uint16_t tag_and_length;    
        if (!GetValue(tag_and_length, data, data_length))
            break;
        
        tag = ( tag_and_length & 0xFFC0) >> 6;
        if (tag == End)
            break;

        tag_len =  tag_and_length & 0x003F;
        if (tag_len == 0x003F)
        {
            if (!GetValue(tag_len, data, data_length))
                break;
        }
                       
        if (tag == DefineBitsLossLess || tag == DefineBitsLossLess2) 
        {                       
            data += sizeof(uint16_t); data_length -= sizeof(uint16_t); // Skip Char Id
            uint8_t bitmap_format;
            
            if (!GetValue(bitmap_format, data, data_length))
                break;
            
            uint16_t bitmap_with;
            if (!GetValue(bitmap_with, data, data_length))
                break;
            
            uint16_t bitmap_height;
            if (!GetValue(bitmap_height, data, data_length))
                break;
            
            uint32_t bitmap_length = tag_len - 7;
            
            uint8_t bitmap_colortable_size = 0;
            if (bitmap_format == 3)
            {
                if (!GetValue(bitmap_colortable_size, data, data_length))                                
                    break;                
                bitmap_length -= 1;
            }
            
            if (data_length < bitmap_length)
                break;
            
            uint8_t * bitmap_bytes = data;
            data += bitmap_length; data_length -= bitmap_length; // Skip bitmap
            
            uint32_t uncompressed_bitmap_length = 0;
            
            uint8_t bytes_per_pixel = 0;
            if (bitmap_colortable_size != 0)
            {
                bytes_per_pixel = 1;                
                uncompressed_bitmap_length += (bitmap_colortable_size + 1 ) * (tag == DefineBitsLossLess ? 3 : 4);                  
                uncompressed_bitmap_length += bitmap_height * ((bitmap_with + 3) / 4); // 32 bit alignment                                
            }
            else 
            {
                bytes_per_pixel = (bitmap_format == 4 ? 2 : 4) ;
                uncompressed_bitmap_length += bitmap_height * ( (bitmap_with * bytes_per_pixel + 3 ) / 4);
            }            
            
            uncompressed_bitmap_length = LE2BE32(uncompressed_bitmap_length);
            QByteArray compressed((const char *)bitmap_bytes, (int)bitmap_length);
            compressed.prepend((const char *)&uncompressed_bitmap_length, sizeof(uncompressed_bitmap_length) );
            
            QByteArray uncompressed = qUncompress(compressed);                                 
                        
            uint32_t uncompressed_length = uncompressed.length();
            char * uncompressed_data = uncompressed.data();
            
            if (bitmap_format == 5)
            {
                for (uint i = 0; i < uncompressed_length / 4; ++i)
                {
                     * (int *)(uncompressed_data + i * 4) = LE2BE32(* (int *)(uncompressed_data + i * 4));
                }
            }
            
            QImage * im = NULL;
            if (bitmap_colortable_size == 0)
            {
                im = new QImage( (const uchar *)uncompressed_data , (int) bitmap_with, (int) bitmap_height, bitmap_format == 4 ?  QImage::Format_RGB555 : QImage::Format_RGB32);
            }
            else
            {
                im = new QImage((const uchar *) uncompressed_data + (bitmap_colortable_size + 1) * (tag == DefineBitsLossLess ? 3 : 4) , (int) bitmap_with, (int) bitmap_height, QImage::Format_Indexed8);
                
                                
                QVector<QRgb> color_table;
                
                
                for (int i = 0; i < bitmap_colortable_size + 1; ++i)
                {
                    QRgb color;
                    
                    if (tag == DefineBitsLossLess)                    
                        color = (uncompressed_data[i * 3] << 16) | (uncompressed_data[i * 3 + 1] << 8) | uncompressed_data[i * 3 + 2];
                    else
                        color = (uncompressed_data[i * 4] << 16) | (uncompressed_data[i * 4 + 1] << 8) | uncompressed_data[i * 4 + 2] | (uncompressed_data[i * 4 + 3] << 24);
                    
                    color_table.append(color);
                }
                
                im->setColorTable(color_table);
            }                        

            im->detach(); 
            
            return QPixmap::fromImage(* im);        
        }
        else
        {            
            data += tag_len;
            data_length -= tag_len;
        }      
    }    
    
    return QPixmap(); 
    
}
 
static bool LoadFileContent(const char * path_to_swf, Header & hdr, uint8_t * &file_content, uint32_t &file_content_length)
{
    FILE * in = fopen(path_to_swf, "rb");
    
    if (in == NULL)    
        return false;    
    
    fseek(in, 0, SEEK_END);
    uint32_t FileLength = ftell(in);
    fseek(in, 0, SEEK_SET);
        
    fread(&hdr, 1, sizeof(hdr), in);
    
    if (strncmp((const char *)hdr.Signature, "FWS", sizeof(hdr.Signature)) != 0 && strncmp((const char *)hdr.Signature, "CWS", sizeof(hdr.Signature)) != 0)    
         return false;                
        
    file_content_length = FileLength - sizeof(hdr);    
    file_content = new uint8_t[file_content_length];
    uint32_t read = fread(file_content, 1, file_content_length, in);
    fclose(in);
    
    if (read != file_content_length)
    {
        delete [] file_content;
        return false;
    }
    
    return true;
}

QPixmap SWFLoader::LoadImageFromSWF(const char * path_to_swf)
{    
    Header hdr;
    uint8_t * file_content = NULL;
    uint32_t file_content_length = 0;
    
    if (!LoadFileContent(path_to_swf, hdr, file_content, file_content_length))
    {
        printf("LoadImageFromSWF: Failed to load \"%s\"\n", path_to_swf);
        return QPixmap();
    }
    
    QByteArray data;
        
    if (hdr.Signature[0] == 'C')
    {
        QByteArray compressed((const char *)file_content, file_content_length);
        uint32_t uncompressed_length = hdr.FileLength - sizeof(hdr);
        uncompressed_length = LE2BE32(uncompressed_length);
        compressed.prepend((char *)&uncompressed_length, sizeof(uncompressed_length));
        data = qUncompress(compressed);               
    }
    else     
    {
        data.setRawData((const char *)file_content, file_content_length);
    }
       
    QPixmap ret = GetFirstImage(data);
    
    delete [] file_content; 
    
    return ret;
}

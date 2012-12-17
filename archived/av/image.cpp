
#include "av_dev.h"
#include "FreeImage.h"

#include <string.h>

struct Image : public av_Image {
	
	FIBITMAP * fImage;
};

av_Image * av_image_load(const char * filename) {
	FREE_IMAGE_FORMAT format = FreeImage_GetFIFFromFilename(filename);
	if(format == FIF_UNKNOWN) {
		printf("image format not recognized: %s\n", filename);
		return 0;
	}
	if(!FreeImage_FIFSupportsReading(format)) {
		printf("image format not supported: %s\n", filename);
		return 0;
	}
	
	FIBITMAP * fImage = FreeImage_Load(format, filename, 0);
	if (fImage == NULL) {
		printf("image failed to load: %s\n", filename);
		return 0;
	}
	
	// color conversions:
	FREE_IMAGE_COLOR_TYPE colorType = FreeImage_GetColorType(fImage);
	switch(colorType) {
		case FIC_MINISBLACK:
		case FIC_MINISWHITE: {
				FIBITMAP *res = FreeImage_ConvertToGreyscale(fImage);
				FreeImage_Unload(fImage);
				fImage = res;
			}
			break;

		case FIC_PALETTE: {
				if(FreeImage_IsTransparent(fImage)) {
					FIBITMAP *res = FreeImage_ConvertTo32Bits(fImage);
					FreeImage_Unload(fImage);
					fImage = res;
				}
				else {
					FIBITMAP *res = FreeImage_ConvertTo24Bits(fImage);
					FreeImage_Unload(fImage);
					fImage = res;
				}
			}
			break;

		case FIC_CMYK: {
				printf("CMYK images currently not supported\n");
				return false;
			}
			break;

		default:
			break;
	}
	
	FREE_IMAGE_TYPE type = FreeImage_GetImageType(fImage);
	BITMAPINFOHEADER * hdr = FreeImage_GetInfoHeader(fImage);
	bool isfloat;
	int bitsize;
	int issigned;
	
	switch(type) {
		case FIT_UINT32: 
			issigned = 0;
			isfloat = 0;
			bitsize = 32;
			break;
		case FIT_INT32: 
			issigned = 1;
			isfloat = 0;
			bitsize = 32;
			break;
//		case FIT_RGBF:
//		case FIT_RGBAF:
//		case FIT_FLOAT: 
//			issigned = 1;
//			isfloat = 1;
//			bitsize = 32;
//			break;
//		case FIT_DOUBLE: 
//			issigned = 1;
//			isfloat = 1;
//			bitsize = 64;
//			break;
		case FIT_BITMAP:
			issigned = 0;
			isfloat = 0;
			bitsize = 8;
			break;
		default: 
			printf("unsupported image data type %d\n", type);
			return 0;
	}
	
	Image * image = new Image();
	image->width = FreeImage_GetWidth(fImage);
	image->height = FreeImage_GetHeight(fImage);
	image->planes = (hdr->biBitCount)/(bitsize);
	
	int bytesize = bitsize / 8;
	int size = image->width * image->height * image->planes * bytesize;
	
	// allocate data:
	image->data = (char *)malloc(size);
	
	switch(image->planes) {
		// LUMINANCE
		case 1: { 
			char *o_pix = image->data;
			int rowstride = bytesize * image->width;
			for(unsigned j = 0; j < image->height; ++j) {
				char * ipix = (char *)FreeImage_GetScanLine(fImage, j);
				memcpy(o_pix, ipix, rowstride);
				o_pix += rowstride;
			}
		}
		break;
		
	/*
	
	
	
		
		// RGB
		case 3: {
			
			
			
			switch(isfloat) {
				case AlloUInt8Ty: {
					char *bp = (char *)(lat.data.ptr);
					int rowstride = lat.header.stride[1];

					for(unsigned j = 0; j < lat.header.dim[1]; ++j) {
						RGBTRIPLE * pix = (RGBTRIPLE *)FreeImage_GetScanLine(fImage, j);
						Image::RGBPix<uint8_t> *o_pix = (Image::RGBPix<uint8_t> *)(bp + j*rowstride);
						for(unsigned i=0; i < lat.header.dim[0]; ++i) {
							o_pix->r = pix->rgbtRed;
							o_pix->g = pix->rgbtGreen;
							o_pix->b = pix->rgbtBlue;
							++pix;
							++o_pix;
						}
					}
				}
				break;

				case AlloFloat32Ty: {
					char *o_pix = (char *)(lat.data.ptr);
					int rowstride = lat.header.stride[1];

					for(unsigned j = 0; j < lat.header.dim[1]; ++j) {
						char *pix = (char *)FreeImage_GetScanLine(fImage, j);
						memcpy(o_pix, pix, rowstride);
						o_pix += rowstride;
					}
				}
				break;

				default: 
				break;

			}
		}
		break;
		
		case Image::RGBA: {
			switch(lat.header.type) {
				case AlloUInt8Ty: {
					char *bp = (char *)(lat.data.ptr);
					int rowstride = lat.header.stride[1];
					for(unsigned j = 0; j < lat.header.dim[1]; ++j) {
						RGBQUAD *pix = (RGBQUAD *)FreeImage_GetScanLine(fImage, j);
						Image::RGBAPix<uint8_t> *o_pix = (Image::RGBAPix<uint8_t> *)(bp + j*rowstride);
						for(unsigned i=0; i < lat.header.dim[0]; ++i) {
							o_pix->r = pix->rgbRed;
							o_pix->g = pix->rgbGreen;
							o_pix->b = pix->rgbBlue;
							o_pix->a = pix->rgbReserved;
							++pix;
							++o_pix;
						}
					}
				}
				break;

				case AlloFloat32Ty: {
					char *o_pix = (char *)(lat.data.ptr);
					int rowstride = lat.header.stride[1];
					for(unsigned j = 0; j < lat.header.dim[1]; ++j) {
						char *pix = (char *)FreeImage_GetScanLine(fImage, j);
						memcpy(o_pix, pix, rowstride);
						o_pix += rowstride;
					}
				}
				break;

				default: break;
			}
		}
		break;
	*/	
		// RGBA:
		case 4: {
			if (bitsize == 8 && !isfloat) {
				// unsigned chars:
				int rowstride = bytesize * image->planes * image->width;
				for(unsigned j = 0; j < image->height; ++j) {
					RGBQUAD * pix = (RGBQUAD *)FreeImage_GetScanLine(fImage, j);
					char * o_pix = image->data + j * rowstride;
					for(unsigned i=0; i < image->width; ++i) {
						*o_pix++ = pix->rgbRed;
						*o_pix++ = pix->rgbGreen;
						*o_pix++ = pix->rgbBlue;
						*o_pix++ = pix->rgbReserved;
						++pix;
					}
				}
			} else {
				printf("image format not supported\n");
				av_image_free(image);
				return 0;
			}

		} 
		break;
		
		default: 
			printf("image data not understood\n");
			av_image_free(image);
			return 0;
	
	}
	return image;
}

void av_image_free(av_Image * ptr) {
	Image * self = (Image *)ptr;
	printf("freeing image %p\n", self);
	if (self->data) {
		free(self->data);
	}
	delete self;
}
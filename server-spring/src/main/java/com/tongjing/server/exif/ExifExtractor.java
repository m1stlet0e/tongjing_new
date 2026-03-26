package com.tongjing.server.exif;

import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import com.drew.metadata.Metadata;
import com.drew.metadata.exif.ExifSubIFDDirectory;
import com.drew.metadata.exif.GpsDirectory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

@Component
public class ExifExtractor {

    private static final Logger log = LoggerFactory.getLogger(ExifExtractor.class);

    /**
     * 从图片中提取 EXIF 元数据，供拍摄信息展示与检索使用。
     *
     * <p>方法名：extract</p>
     */
    public Map<String, Object> extract(byte[] imageBytes) {
        Map<String, Object> out = emptyExif();
        try {
            Metadata metadata = ImageMetadataReader.readMetadata(new ByteArrayInputStream(imageBytes));
            ExifSubIFDDirectory exif = metadata.getFirstDirectoryOfType(ExifSubIFDDirectory.class);
            if (exif != null) {
                if (exif.getString(ExifSubIFDDirectory.TAG_MAKE) != null) {
                    out.put("camera_brand", exif.getString(ExifSubIFDDirectory.TAG_MAKE));
                }
                if (exif.getString(ExifSubIFDDirectory.TAG_MODEL) != null) {
                    out.put("camera_model", exif.getString(ExifSubIFDDirectory.TAG_MODEL));
                }
                if (exif.getString(ExifSubIFDDirectory.TAG_LENS_MODEL) != null) {
                    out.put("lens_model", exif.getString(ExifSubIFDDirectory.TAG_LENS_MODEL));
                }
                if (exif.getRational(ExifSubIFDDirectory.TAG_FOCAL_LENGTH) != null) {
                    double f = exif.getRational(ExifSubIFDDirectory.TAG_FOCAL_LENGTH).doubleValue();
                    out.put("focal_length", Math.round(f) + "mm");
                }
                if (exif.getRational(ExifSubIFDDirectory.TAG_FNUMBER) != null) {
                    double fn = exif.getRational(ExifSubIFDDirectory.TAG_FNUMBER).doubleValue();
                    out.put("aperture", "F" + fn);
                }
                if (exif.getString(ExifSubIFDDirectory.TAG_EXPOSURE_TIME) != null) {
                    out.put("shutter_speed", exif.getString(ExifSubIFDDirectory.TAG_EXPOSURE_TIME));
                } else if (exif.getRational(ExifSubIFDDirectory.TAG_EXPOSURE_TIME) != null) {
                    double exp = exif.getRational(ExifSubIFDDirectory.TAG_EXPOSURE_TIME).doubleValue();
                    if (exp > 0 && exp < 1) {
                        out.put("shutter_speed", "1/" + Math.round(1 / exp) + "s");
                    } else {
                        out.put("shutter_speed", exp + "s");
                    }
                }
                Integer iso = exif.getInteger(ExifSubIFDDirectory.TAG_ISO_EQUIVALENT);
                if (iso != null) {
                    out.put("iso", iso);
                }
            }
            GpsDirectory gps = metadata.getFirstDirectoryOfType(GpsDirectory.class);
            if (gps != null && gps.getGeoLocation() != null) {
                out.put("latitude", gps.getGeoLocation().getLatitude());
                out.put("longitude", gps.getGeoLocation().getLongitude());
            }
        } catch (IOException | ImageProcessingException e) {
            log.debug("EXIF parse skipped: {}", e.getMessage());
        }
        return out;
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：emptyExif</p>
     */
    private static Map<String, Object> emptyExif() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("camera_brand", null);
        m.put("camera_model", null);
        m.put("lens_model", null);
        m.put("focal_length", null);
        m.put("aperture", null);
        m.put("shutter_speed", null);
        m.put("iso", null);
        m.put("latitude", null);
        m.put("longitude", null);
        m.put("create_time", null);
        return m;
    }
}

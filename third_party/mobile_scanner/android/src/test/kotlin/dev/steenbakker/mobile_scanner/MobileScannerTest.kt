package dev.steenbakker.mobile_scanner

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Point
import android.media.Image
import androidx.camera.core.ImageInfo
import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.OnCanceledListener
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.view.TextureRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSystemClock
import org.robolectric.util.ReflectionHelpers
import java.time.Duration
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * These run on Robolectric, which provides working implementations of the Android framework
 * classes that `isBarcodeInScanWindow` depends on. Against the stub `android.jar` that plain
 * JVM unit tests use, `Rect` and `Point` throw on every call.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew :mobile_scanner:testDebugUnitTest` in the `example/android/`
 * directory, or you can run them directly from IDEs that support JUnit such as Android Studio.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
internal class MobileScannerTest {

    private fun createMobileScanner(
        barcodeScanner: BarcodeScanner = Mockito.mock(BarcodeScanner::class.java),
        mobileScannerCallback: MobileScannerCallback = { _, _, _, _ -> },
        inputImageFactory: (Image, Int) -> InputImage = { _, _ ->
            Mockito.mock(InputImage::class.java)
        },
    ): MobileScanner {
        return MobileScanner(
            Mockito.mock(Activity::class.java),
            Mockito.mock(TextureRegistry::class.java),
            mobileScannerCallback,
            { _: String -> },
            Mockito.mock(DeviceOrientationListener::class.java),
            { _: BarcodeScannerOptions? -> barcodeScanner },
            inputImageFactory,
        ).also { it.scanner = barcodeScanner }
    }

    private fun createBarcode(vararg cornerPoints: Point): Barcode {
        val barcode = Mockito.mock(Barcode::class.java)

        Mockito.`when`(barcode.cornerPoints).thenReturn(arrayOf(*cornerPoints))

        return barcode
    }

    private fun createImage(width: Int, height: Int): ImageProxy {
        val imageInfo = Mockito.mock(ImageInfo::class.java)

        Mockito.`when`(imageInfo.rotationDegrees).thenReturn(0)

        val image = Mockito.mock(ImageProxy::class.java)

        Mockito.`when`(image.imageInfo).thenReturn(imageInfo)
        Mockito.`when`(image.width).thenReturn(width)
        Mockito.`when`(image.height).thenReturn(height)

        return image
    }

    // A barcode occupying the middle of a 400x400 image.
    private fun createBarcodeInCenter(): Barcode = createBarcode(
        Point(150, 150),
        Point(250, 150),
        Point(250, 250),
        Point(150, 250),
    )

    @Test
    fun isBarcodeInScanWindow_canHandleNaNValues() {
        // Intentional suppression for the mock value in the test,
        // since there is no NaN constant.
        @Suppress("DIVISION_BY_ZERO")
        val notANumber = 0.0f / 0.0f

        // A scan window that covers the entire image, and so would contain the barcode,
        // except that one of its dimensions is invalid. Rounding NaN fails, and we want
        // `false` rather than a false positive.
        val scanWindow: List<Float> = listOf(0f, notANumber, 1f, 1f)

        assertFalse(
            createMobileScanner().isBarcodeInScanWindow(
                scanWindow,
                createBarcodeInCenter(),
                createImage(400, 400),
            )
        )
    }

    @Test
    fun isBarcodeInScanWindow_barcodeInsideScanWindow_returnsTrue() {
        // A scan window that covers the entire image.
        val scanWindow: List<Float> = listOf(0f, 0f, 1f, 1f)

        assertTrue(
            createMobileScanner().isBarcodeInScanWindow(
                scanWindow,
                createBarcodeInCenter(),
                createImage(400, 400),
            )
        )
    }

    @Test
    fun isBarcodeInScanWindow_barcodeOutsideScanWindow_returnsFalse() {
        // A scan window that covers only the top left quarter of the image,
        // which the barcode in the center falls outside of.
        val scanWindow: List<Float> = listOf(0f, 0f, 0.25f, 0.25f)

        assertFalse(
            createMobileScanner().isBarcodeInScanWindow(
                scanWindow,
                createBarcodeInCenter(),
                createImage(400, 400),
            )
        )
    }

    @Test
    fun isBarcodeInScanWindow_barcodeWithoutCornerPoints_returnsFalse() {
        val scanWindow: List<Float> = listOf(0f, 0f, 1f, 1f)

        val barcode = Mockito.mock(Barcode::class.java)

        Mockito.`when`(barcode.cornerPoints).thenReturn(null)

        assertFalse(
            createMobileScanner().isBarcodeInScanWindow(
                scanWindow,
                barcode,
                createImage(400, 400),
            )
        )
    }

    @Test
    fun captureOutput_closesImageProxyWhenMediaImageIsNull() {
        val mobileScanner = createMobileScanner()
        val imageProxy = Mockito.mock(ImageProxy::class.java)

        Mockito.`when`(imageProxy.image).thenReturn(null)

        mobileScanner.captureOutput.analyze(imageProxy)

        Mockito.verify(imageProxy).close()
    }

    @Test
    fun captureOutput_closesImageProxyWhenBarcodeProcessingFails() {
        val barcodeScanner = Mockito.mock(BarcodeScanner::class.java)
        @Suppress("UNCHECKED_CAST")
        val processingTask = Mockito.mock(Task::class.java) as Task<List<Barcode>>
        val inputImage = Mockito.mock(InputImage::class.java)
        val mobileScanner = createMobileScanner(barcodeScanner) { _, _ -> inputImage }
        val imageProxy = Mockito.mock(ImageProxy::class.java)
        val imageInfo = Mockito.mock(ImageInfo::class.java)

        Mockito.`when`(imageProxy.image).thenReturn(Mockito.mock(Image::class.java))
        Mockito.`when`(imageProxy.imageInfo).thenReturn(imageInfo)
        Mockito.`when`(imageInfo.rotationDegrees).thenReturn(0)
        Mockito.`when`(barcodeScanner.process(inputImage)).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnSuccessListener(Mockito.any())).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnFailureListener(Mockito.any())).thenReturn(processingTask)

        mobileScanner.captureOutput.analyze(imageProxy)

        val failureListener = ArgumentCaptor.forClass(OnFailureListener::class.java)
        Mockito.verify(processingTask).addOnFailureListener(failureListener.capture())
        failureListener.value.onFailure(IllegalStateException("ML Kit failure"))

        Mockito.verify(imageProxy, Mockito.times(1)).close()
    }

    @Test
    fun captureOutput_closesImageProxyWhenNoBarcodeIsDetected() {
        val barcodeScanner = Mockito.mock(BarcodeScanner::class.java)
        @Suppress("UNCHECKED_CAST")
        val processingTask = Mockito.mock(Task::class.java) as Task<List<Barcode>>
        val inputImage = Mockito.mock(InputImage::class.java)
        val mobileScanner = createMobileScanner(barcodeScanner) { _, _ -> inputImage }
        val imageProxy = Mockito.mock(ImageProxy::class.java)
        val imageInfo = Mockito.mock(ImageInfo::class.java)

        Mockito.`when`(imageProxy.image).thenReturn(Mockito.mock(Image::class.java))
        Mockito.`when`(imageProxy.imageInfo).thenReturn(imageInfo)
        Mockito.`when`(imageInfo.rotationDegrees).thenReturn(0)
        Mockito.`when`(barcodeScanner.process(inputImage)).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnSuccessListener(Mockito.any())).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnFailureListener(Mockito.any())).thenReturn(processingTask)

        mobileScanner.captureOutput.analyze(imageProxy)

        @Suppress("UNCHECKED_CAST")
        val successListener = ArgumentCaptor.forClass(OnSuccessListener::class.java)
            as ArgumentCaptor<OnSuccessListener<List<Barcode>>>
        Mockito.verify(processingTask).addOnSuccessListener(successListener.capture())
        successListener.value.onSuccess(emptyList())

        Mockito.verify(imageProxy, Mockito.times(1)).close()
    }

    @Test
    fun captureOutput_returnsImagesWithoutBarcodesAtMostTwicePerSecond() {
        val barcodeScanner = Mockito.mock(BarcodeScanner::class.java)
        val inputImage = Mockito.mock(InputImage::class.java)
        val images = LinkedBlockingQueue<ByteArray>()
        val mobileScanner = createMobileScanner(
            barcodeScanner,
            mobileScannerCallback = { _, image, _, _ ->
                if (image != null) images.offer(image)
            },
        ) { _, _ -> inputImage }
        ReflectionHelpers.setField(mobileScanner, "returnImage", true)

        fun deliverEmptyFrame(): ImageProxy {
            @Suppress("UNCHECKED_CAST")
            val task = Mockito.mock(Task::class.java) as Task<List<Barcode>>
            val imageProxy = createImage(4, 4)
            Mockito.`when`(imageProxy.image).thenReturn(Mockito.mock(Image::class.java))
            Mockito.`when`(imageProxy.toBitmap())
                .thenReturn(Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888))
            Mockito.`when`(barcodeScanner.process(inputImage)).thenReturn(task)
            Mockito.`when`(task.addOnSuccessListener(Mockito.any())).thenReturn(task)
            Mockito.`when`(task.addOnFailureListener(Mockito.any())).thenReturn(task)

            mobileScanner.captureOutput.analyze(imageProxy)
            @Suppress("UNCHECKED_CAST")
            val success = ArgumentCaptor.forClass(OnSuccessListener::class.java)
                as ArgumentCaptor<OnSuccessListener<List<Barcode>>>
            Mockito.verify(task).addOnSuccessListener(success.capture())
            success.value.onSuccess(emptyList())
            return imageProxy
        }

        val first = deliverEmptyFrame()
        assertNotNull(images.poll(5, TimeUnit.SECONDS))
        Mockito.verify(first, Mockito.timeout(1000).times(1)).close()

        val throttled = deliverEmptyFrame()
        Mockito.verify(throttled, Mockito.times(1)).close()
        assertNull(images.poll())

        ShadowSystemClock.advanceBy(Duration.ofMillis(500))
        val next = deliverEmptyFrame()
        assertNotNull(images.poll(5, TimeUnit.SECONDS))
        Mockito.verify(next, Mockito.timeout(1000).times(1)).close()
    }

    @Test
    fun captureOutput_closesImageProxyWhenBarcodeProcessingIsCanceled() {
        val barcodeScanner = Mockito.mock(BarcodeScanner::class.java)
        @Suppress("UNCHECKED_CAST")
        val processingTask = Mockito.mock(Task::class.java) as Task<List<Barcode>>
        val inputImage = Mockito.mock(InputImage::class.java)
        val mobileScanner = createMobileScanner(barcodeScanner) { _, _ -> inputImage }
        val imageProxy = Mockito.mock(ImageProxy::class.java)
        val imageInfo = Mockito.mock(ImageInfo::class.java)

        Mockito.`when`(imageProxy.image).thenReturn(Mockito.mock(Image::class.java))
        Mockito.`when`(imageProxy.imageInfo).thenReturn(imageInfo)
        Mockito.`when`(imageInfo.rotationDegrees).thenReturn(0)
        Mockito.`when`(barcodeScanner.process(inputImage)).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnSuccessListener(Mockito.any())).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnFailureListener(Mockito.any())).thenReturn(processingTask)
        Mockito.`when`(processingTask.addOnCanceledListener(Mockito.any())).thenReturn(processingTask)

        mobileScanner.captureOutput.analyze(imageProxy)

        val canceledListener = ArgumentCaptor.forClass(OnCanceledListener::class.java)
        Mockito.verify(processingTask).addOnCanceledListener(canceledListener.capture())
        canceledListener.value.onCanceled()

        Mockito.verify(imageProxy, Mockito.times(1)).close()
    }

    @Test
    fun captureOutput_closesImageProxyWhenProcessingThrowsSynchronously() {
        val barcodeScanner = Mockito.mock(BarcodeScanner::class.java)
        val inputImage = Mockito.mock(InputImage::class.java)
        val mobileScanner = createMobileScanner(barcodeScanner) { _, _ -> inputImage }
        val imageProxy = Mockito.mock(ImageProxy::class.java)
        val imageInfo = Mockito.mock(ImageInfo::class.java)

        Mockito.`when`(imageProxy.image).thenReturn(Mockito.mock(Image::class.java))
        Mockito.`when`(imageProxy.imageInfo).thenReturn(imageInfo)
        Mockito.`when`(imageInfo.rotationDegrees).thenReturn(0)
        Mockito.`when`(barcodeScanner.process(inputImage))
            .thenThrow(IllegalStateException("Synchronous ML Kit failure"))

        mobileScanner.captureOutput.analyze(imageProxy)

        Mockito.verify(imageProxy, Mockito.times(1)).close()
    }
}

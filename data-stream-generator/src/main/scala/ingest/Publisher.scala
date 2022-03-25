package ingest

import java.util.concurrent.Executors

import com.codahale.metrics.Meter
import org.slf4j.LoggerFactory

import scala.annotation.tailrec
import scala.concurrent.{ExecutionContext, Future}

trait Publisher extends Serializable {
  implicit val ec = ExecutionContext.fromExecutor(Executors.newFixedThreadPool(8))
  val logger = LoggerFactory.getLogger(getClass)

  // log some stats every 5 seconds
  private val statsLogger = Future {
    @tailrec def logStats(): Unit = {
      logger.info(f"Generator stats - addToCart (count:${addToCartStats.getCount}, rate:${addToCartStats.getOneMinuteRate}%.1f /min), " +
        f"checkout (count:${checkoutStats.getCount}, rate:${checkoutStats.getOneMinuteRate}%.1f /min)" +
        f"restock (count:${restockStats.getCount}, rate:${restockStats.getOneMinuteRate}%.1f /min)"
      )
      Thread.sleep(5000)
      logStats()
    }

    logStats()
  }

  val addToCartStats = new Meter()
  val checkoutStats = new Meter()
  val restockStats = new Meter()

  val flowStats = new Meter()
  val speedStats = new Meter()

  def publish(index: Int): Future[Unit]
}
